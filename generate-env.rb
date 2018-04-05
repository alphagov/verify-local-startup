#!/usr/bin/env ruby

require 'optparse'
require 'dotenv'

Dotenv.load('config/ports.env')

if not Dir.exists? 'data'
  `command -v cfssl || brew install cfssl`
  `./generate/hub-dev-pki.sh`
end

COMMON = <<~COMMON
    ### APPS
    METADATA_TRUST_STORE=#{`base64 data/pki/metadata.ts`}
    METADATA_TRUST_STORE_PASSWORD=marshmallow
  COMMON

MSA = <<~MSA
    ### MSA
    HUB_TRUST_STORE=#{`base64 data/pki/hub.ts`}
    MSA_SIGNING_KEY_PRIMARY=#{`base64 data/pki/sample_rp_msa_signing_primary.pk8`}
    MSA_SIGNING_CERT_PRIMARY=#{`base64 data/pki/sample_rp_msa_signing_primary.crt`}
    MSA_SIGNING_KEY_SECONDARY=#{`base64 data/pki/sample_rp_msa_signing_secondary.pk8`}
    MSA_SIGNING_CERT_SECONDARY=#{`base64 data/pki/sample_rp_msa_signing_secondary.crt`}
    MSA_ENCRYPTION_KEY_PRIMARY=#{`base64 data/pki/sample_rp_msa_encryption_primary.pk8`}
    MSA_ENCRYPTION_CERT_PRIMARY=#{`base64 data/pki/sample_rp_msa_encryption_primary.crt`}
  MSA

VSP = <<~VSP
    ### VSP
    MSA_METADATA_URL=http://localhost:#{ENV['TEST_RP_MSA_PORT']}/matching-service/SAML2/metadata
    MSA_ENTITY_ID=http://dev-rp-ms.local/SAML2/MD
    SERVICE_ENTITY_IDS='["http://dev-rp.local/SAML2/MD"]'
    VERIFY_ENVIRONMENT=COMPLIANCE_TOOL
    SAML_SIGNING_KEY=#{`base64 data/pki/sample_rp_signing_primary.pk8`}
    SAML_PRIMARY_ENCRYPTION_KEY=#{`base64 data/pki/sample_rp_encryption_primary.pk8`}

  VSP

TESTRP = <<~TESTRP
    ### TESTRP

    # WARNING: re-uses some VSP config
    
    TEST_RP_ENTITY_ID="http://dev-rp.local/SAML2/MD" # perhaps we want a different one from VSP?
    TEST_RP_SIGNING_KEY=#{`base64 data/pki/sample_rp_signing_primary.pk8`}
    TEST_RP_SIGNING_CERT=#{`base64 data/pki/sample_rp_signing_primary.crt`}
    TEST_RP_ENCRYPTION_KEY=#{`base64 data/pki/sample_rp_encryption_primary.pk8`}
    TEST_RP_ENCRYPTION_CERT=#{`base64 data/pki/sample_rp_encryption_primary.crt`}

TESTRP

IDP = <<~IDP
    ### IDP
    LOG_PATH=logs
    KEY_TYPE=encoded
    STUB_IDP_SIGNING_PRIVATE_KEY=#{`base64 data/pki/stub_idp_signing_primary.pk8`}
    CERT_TYPE=encoded
    STUB_IDP_SIGNING_CERT=#{`base64 data/pki/stub_idp_signing_primary.crt`}
    STUB_IDP_BASIC_AUTH=false
    METADATA_ENTITY_ID=https://dev-hub.local
    STUB_IDPS_FILE_PATH="../verify-local-startup/configuration/idps/stub-idps.yml"
    INFINISPAN_PERSISTENCE=false
    TRUSTSTORE_TYPE=encoded
    METADATA_TRUSTSTORE=#{`base64 data/pki/metadata.ts`}
    TRUSTSTORE_PASSWORD=marshmallow
    EUROPEAN_IDENTITY_ENABLED=true
    STUB_COUNTRY_SIGNING_PRIVATE_KEY="$STUB_IDP_SIGNING_PRIVATE_KEY"
    STUB_COUNTRY_SIGNING_CERT="$STUB_IDP_SIGNING_CERT"
    DB_URI="jdbc:postgresql://localhost:5432/postgres?user=postgres"
  IDP

applications = {
    MSA: MSA,
    VSP: VSP,
    IDP: IDP,
    TESTRP: TESTRP
}

apps = applications.keys
file = 'local.env'
ARGV << '-h' if ARGV.empty?

OptionParser.new do |opts|
  opts.banner = "Usage: generate-env.rb [-a/apps]"

  opts.on("-f file", "--f file",) do |f|
    puts f
    file = f
  end

  opts.on("-a a1,a2,a3", "--apps a1,a2,a3", Array) do |a|
    apps = a.map { |e| e.upcase.to_sym }
  end
end.parse!

unless apps.all? {|a| applications.has_key? a}
  puts "No configuration exists for apps: #{apps} - valid choices are #{applications.keys}"
  exit 1
end

open(file, 'w') { |f|
  f.puts(File.read('config/ports.env'))
  f.puts COMMON
  for app in apps
    f.puts applications[app]
  end
}

puts "Wrote environment to #{file}"
