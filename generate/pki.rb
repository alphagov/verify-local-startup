#!/usr/bin/env ruby

require 'yaml'
require 'fileutils'

SCRIPT_DIR = File.expand_path(File.dirname(__FILE__))
pki_to_generate = YAML.load_file(ARGV[0] ||= "#{SCRIPT_DIR}/pki.yml")
pki_dir = 'pki'
FileUtils::mkdir_p pki_dir
Dir.chdir pki_dir

def generate_cert(type, common_name, file, ca_cert, ca_key)
    command = <<-COMMAND
      sed 's/$COMMON_NAME/#{common_name}/' #{SCRIPT_DIR}/template-csr.json | \
      cfssl gencert -config #{SCRIPT_DIR}/cfssl-config.json -profile "#{type}" -ca #{ca_cert} -ca-key #{ca_key} /dev/stdin | \
      cfssljson -bare #{file}
    COMMAND
    `#{command}`
end

def convert_key_cert(file)
    `openssl pkcs8 -topk8 -inform PEM -outform DER -in #{file}-key.pem -out #{file}.pk8 -nocrypt`
    FileUtils.move "#{file}.pem", "#{file}.crt"
    FileUtils.remove [ "#{file}-key.pem", "#{file}.csr" ]
end

pki_to_generate['pki'].each do |ca_name, ca|
  puts "Generate key/cert for Root CA: #{ca_name}"
  `sed 's/$COMMON_NAME/#{ca['common-name']}/' #{SCRIPT_DIR}/template-csr.json | cfssl genkey -initca /dev/stdin | cfssljson -bare #{ca['cert-file']}`

  ca['intermediates'].each do |inter_name, inter|
    # Need to change values in the hash so that future access also gets these defaults
    inter['common-name'] = inter.fetch('common-name', "Verify Local Startup #{inter_name.capitalize} Intermediate CA")
    inter['cert-file'] = inter.fetch('cert-file', "#{ca_name}-#{inter_name}")

    puts "Generate key/cert for intermediate CA: #{inter_name}"
    generate_cert('intermediate',
                  inter['common-name'],
                  inter['cert-file'],
                  "#{ca['cert-file']}.pem",
                  "#{ca['cert-file']}-key.pem")

    inter['certs'].each do |cert_name, cert|
      cert_file = cert.fetch('cert-file', cert_name)
      common_name = cert.fetch('common-name', "Verify Local Startup #{cert_name.split("-").map{ |s| s.capitalize}.join(' ')}"),
      generate_cert(cert['type'],
                    common_name,
                    cert_file,
                    "#{inter['cert-file']}.pem",
                    "#{inter['cert-file']}-key.pem")
      convert_key_cert cert_file
    end
    convert_key_cert inter['cert-file']
  end
  convert_key_cert ca['cert-file']
end
