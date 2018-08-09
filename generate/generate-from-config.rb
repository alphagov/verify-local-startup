#!/usr/bin/env ruby

require 'yaml'
require 'json'
require 'fileutils'
require 'open3'
require 'verify/metadata/generator'
require_relative 'metadata-sources'

SCRIPT_DIR = File.expand_path(File.dirname(__FILE__))
DATA_DIR = "#{SCRIPT_DIR}/../data"
config = YAML.load_file(ARGV[0] ||= "#{SCRIPT_DIR}/config.yml")

def csr_json()
  '{"key": { "algo": "rsa", "size": 2048 }, "names": [ { "C": "GB", "ST": "London", "L": "London", "O": "Cabinet Office", "OU": "GDS" } ]}'
end

def generate_cert(type, common_name, file, ca_cert, ca_key)
  gencert_out, gencert_err, gencert_status = Open3.capture3(
    'cfssl', 'gencert',
    '-config', "#{SCRIPT_DIR}/cfssl-config.json",
    '-cn', common_name,
    '-ca', ca_cert,
    '-ca-key', ca_key,
    '-profile', type,
    '-hostname', 'localhost',
    '-loglevel=2', '-',
    :stdin_data => csr_json
  )

  raise gencert_err unless gencert_status.success?
  cfssl_json(gencert_out, file)
end

def cfssl_json(input, file)
  write_out, write_status = Open3.capture2e(
    'cfssljson',
    '-bare', file,
    stdin_data: input
  )

  raise write_out unless write_status.success?
end

def lookup_element(config, key)
    config['pki'].dig(*key.split('.'))
end

def lookup_cert_file(config, key)
    "#{DATA_DIR}/pki/#{lookup_element(config, key)['cert-file']}.crt"
end

def lookup_key_file(config, key)
    "#{DATA_DIR}/pki/#{lookup_element(config, key)['cert-file']}-key.pem"
end

def convert_key_cert(file)
  openssl_output = %x(openssl pkcs8 -topk8 -inform PEM -outform DER -in #{file}-key.pem -out #{file}.pk8 -nocrypt)
  raise openssl_output unless $?.success?
  FileUtils.move "#{file}.pem", "#{file}.crt"
  FileUtils.remove [ "#{file}-key.pem", "#{file}.csr" ]
end

pki_dir = "#{DATA_DIR}/pki"
ca_dir = "#{DATA_DIR}/ca-certificates"
FileUtils::mkdir_p pki_dir
Dir.chdir pki_dir
config['pki'].each do |ca_name, ca|
  puts "Generating Root CA: #{ca_name}"
  genkey_out, genkey_err, genkey_status = Open3.capture3('cfssl', 'genkey', '-initca', '-loglevel=2', '-cn', ca['common-name'], '-', :stdin_data => csr_json)
  raise genkey_err unless genkey_status.success?

  cfssl_json(genkey_out, ca['cert-file'])

  ca['intermediates'].each do |inter_name, inter|
    # Need to change values in the hash so that future access also gets these defaults
    inter['common-name'] = inter.fetch('common-name', "Verify Local Startup #{inter_name.capitalize} Intermediate CA")
    inter['cert-file'] = inter.fetch('cert-file', "#{ca_name}-#{inter_name}")

    puts "\tGenerating Intermediate CA: #{inter_name}"
    generate_cert('intermediate', inter['common-name'], inter['cert-file'], "#{ca['cert-file']}.pem", "#{ca['cert-file']}-key.pem")

    inter['certs'].each do |cert_name, cert|
      puts "\t\tGenerating cert: #{cert_name}"
      cert['cert-file'] = cert.fetch('cert-file', cert_name)
      common_name = cert.fetch('common-name', "Verify Local Startup #{cert_name.split("-").map{ |s| s.capitalize}.join(' ')}")
      generate_cert(cert['type'],
                    common_name,
                    cert['cert-file'],
                    "#{inter['cert-file']}.pem",
                    "#{inter['cert-file']}-key.pem")
      convert_key_cert cert['cert-file']
    end
    convert_key_cert inter['cert-file']
    FileUtils.move "#{inter['cert-file']}.crt", ca_dir
    FileUtils.remove [ "#{inter['cert-file']}.pk8" ]
  end
  convert_key_cert ca['cert-file']
  FileUtils.move "#{ca['cert-file']}.crt", ca_dir
  FileUtils.remove [ "#{ca['cert-file']}.pk8" ]
end

config.fetch('truststores', []).each do |store, details|
  puts "Generating truststore: #{store}"
  details['certs'].each do |cert|
    cert_element = lookup_element(config, cert)
    cert_file = "#{ca_dir}/#{cert_element['cert-file']}.crt"
    puts "\tAdding #{cert_file} to #{store}"
    `keytool -import -noprompt -alias "#{cert_element['common-name']}" -file "#{cert_file}" -keystore "#{store}.ts" -storepass marshmallow`
  end
end

metadata_dir = "#{DATA_DIR}/metadata"
FileUtils::mkdir_p "#{metadata_dir}/dev"
FileUtils::mkdir_p "#{metadata_dir}/compliance-tool"
Dir.chdir metadata_dir
metadata = config.fetch('metadata', nil)
if metadata then
  Metadata.generate_metadata_sources(lookup_cert_file(config, metadata['hub']['signing']),
                                     lookup_cert_file(config, metadata['hub']['encryption']),
                                     lookup_cert_file(config, metadata['idps']['signing']),
                                     "dev",
                                     ENV.fetch('FRONTEND_URI'),
                                     ENV.fetch('STUB_IDP_URI'))

  Metadata.generate_metadata_sources(lookup_cert_file(config, metadata['hub']['signing']),
                                     lookup_cert_file(config, metadata['hub']['encryption']),
                                     lookup_cert_file(config, metadata['idps']['signing']),
                                     "compliance-tool",
                                     "http://localhost:#{ENV.fetch('COMPLIANCE_TOOL_PORT', 50270)}",
                                     ENV.fetch('STUB_IDP_URI'))

  Verify::Metadata::Generator::run!(['-c', metadata_dir, '-e', 'dev', '-w', '-o',
    "#{metadata_dir}",
    '--valid-until=36500',
    '--hubCA', "#{ca_dir}/verify-root.crt",
    '--hubCA', "#{ca_dir}/verify-hub.crt",
    '--idpCA', "#{ca_dir}/verify-root.crt",
    '--idpCA', "#{ca_dir}/verify-idp.crt"])

  write_out, write_status = Open3.capture2e(
    'xmlsectool', '--sign',
    '--inFile', "#{metadata_dir}/dev/metadata.xml",
    '--outFile', "#{metadata_dir}/dev.xml",
    '--certificate', "#{pki_dir}/metadata_signing_a.crt",
    '--key', "#{pki_dir}/metadata_signing_a.pk8",
    '--digest', 'SHA-256'
  )
  raise write_out unless write_status.success?
end
