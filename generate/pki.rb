#!/usr/bin/env ruby

require 'yaml'
require 'json'
require 'fileutils'

SCRIPT_DIR = File.expand_path(File.dirname(__FILE__))
pki_to_generate = YAML.load_file(ARGV[0] ||= "#{SCRIPT_DIR}/pki.yml")
pki_dir = 'pki'
FileUtils::mkdir_p pki_dir
Dir.chdir pki_dir

def get_template_csr(common_name)
  {
      "CN": common_name,
      "hosts": [ "localhost" ],
      "key": {
          "algo": "rsa",
          "size": 2048
      },
      "names": [
          {
              "C": "GB",
              "ST": "London",
              "L": "London",
              "O": "Cabinet Office",
              "OU": "GDS"
          }
      ]
  }.to_json
end

def generate_cert(type, common_name, file, ca_cert, ca_key)
  output = %x(echo '#{get_template_csr(common_name)}' | \
              cfssl gencert -config #{SCRIPT_DIR}/cfssl-config.json -profile "#{type}" -ca #{ca_cert} -ca-key #{ca_key} -loglevel=2 - | \
              cfssljson -bare #{file})
  raise output unless $?.success?
end

def convert_key_cert(file)
  openssl_output = %x(openssl pkcs8 -topk8 -inform PEM -outform DER -in #{file}-key.pem -out #{file}.pk8 -nocrypt)
  raise openssl_output unless $?.success?
  FileUtils.move "#{file}.pem", "#{file}.crt"
  FileUtils.remove [ "#{file}-key.pem", "#{file}.csr" ]
end

pki_to_generate['pki'].each do |ca_name, ca|
  puts "Generating Root CA: #{ca_name}"
  output = %x(echo '#{get_template_csr(ca['common-name'])}' | cfssl genkey -initca -loglevel=2 - | cfssljson -bare #{ca['cert-file']})
  raise output unless $?.success?

  ca['intermediates'].each do |inter_name, inter|
    # Need to change values in the hash so that future access also gets these defaults
    inter['common-name'] = inter.fetch('common-name', "Verify Local Startup #{inter_name.capitalize} Intermediate CA")
    inter['cert-file'] = inter.fetch('cert-file', "#{ca_name}-#{inter_name}")

    puts "\tGenerating Intermediate CA: #{inter_name}"
    generate_cert('intermediate',
                  inter['common-name'],
                  inter['cert-file'],
                  "#{ca['cert-file']}.pem",
                  "#{ca['cert-file']}-key.pem")

    inter['certs'].each do |cert_name, cert|
      cert_file = cert.fetch('cert-file', cert_name)
      common_name = cert.fetch('common-name', "Verify Local Startup #{cert_name.split("-").map{ |s| s.capitalize}.join(' ')}")
      puts "\t\tGenerating cert: #{cert_name}"
      generate_cert(cert['type'],
                    common_name,
                    cert_file,
                    "#{inter['cert-file']}.pem",
                    "#{inter['cert-file']}-key.pem")
      convert_key_cert cert_file
    end
    convert_key_cert inter['cert-file']
    FileUtils.remove [ "#{inter['cert-file']}.pk8" ]
  end
  convert_key_cert ca['cert-file']
  FileUtils.remove [ "#{ca['cert-file']}.pk8" ]
end
