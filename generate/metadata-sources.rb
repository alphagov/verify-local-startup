#!/usr/bin/env ruby

require 'yaml'

def block_cert(cert)
  IO.readlines(cert).map(&:strip).reject(&:empty?)[1 ... -1].join("\n")
end

def inline_cert(cert)
  IO.readlines(cert).map(&:strip).reject(&:empty?)[1 ... -1].join
end

if ARGV.size < 4
  puts "Usage: metadata-sources.rb hub_signing_cert hub_encryption_cert idp_signing_cert output_dir"
  exit 1
end

hub_signing_cert = ARGV[0]
hub_encryption_cert = ARGV[1]
idp_signing_cert = ARGV[2]
output_dir = ARGV[3]

idps = {
  'Stub IDP One' => 'stub-idp-one',
  'Stub IDP Two' => 'stub-idp-two',
  'Stub IDP Three' => 'stub-idp-three',
  'Stub IDP Four' => 'stub-idp-four',
  'Stub IDP Demo' => 'stub-idp-demo'
}

hub_yaml = {
  'id' => 'VERIFY-HUB',
  'entity_id' => "#{ENV.fetch('HUB_CONNECTOR_ENTITY_ID')}",
  'assertion_consumer_service_uri' => "#{ENV.fetch('FRONTEND_URL')}/SAML2/SSO/Response/POST",
  'organization' => { 'name' => 'Hub', 'url' => 'http://localhost', 'display_name' => 'Hub' },
  'signing_certificates' => [
    { 'name' => 'signing_primary', 'x509' => block_cert(hub_signing_cert) }
  ],
  'encryption_certificate' => { 'name' => 'encryption', 'x509' => block_cert(hub_encryption_cert) }
}

idp_yaml = {
  'enabled' => true,
  'signing_certificates' => [
    { 'name' => 'signing_primary', 'x509' => inline_cert(idp_signing_cert) }
  ],
}

Dir::chdir(output_dir) do
  File.open('hub.yml', 'w') { |f| f.write(YAML.dump(hub_yaml)) }

  idps.each do |name, id|
    yaml = idp_yaml.update(
      'organization' => { 'name' => id, 'url' => "http://#{id}.local", 'display_name' => name},
      'entity_id' => "http://#{id}.local/SSO/POST",
      'sso_uri' => "#{ENV.fetch('STUB_IDP_URL')}/#{id}/SAML2/SSO",
      'id' => id
    )
    File.open(File.join('idps', "#{id}.yml"), 'w') { |f| f.write(YAML.dump(yaml)) }
  end
end

Dir::chdir(output_dir + "-connector") do
  hub_yaml.update('assertion_consumer_service_uri' => "#{ENV.fetch('FRONTEND_URL')}/SAML2/SSO/EidasResponse/POST")
  File.open('hub.yml', 'w') { |f| f.write(YAML.dump(hub_yaml)) }
end
