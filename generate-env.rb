#!/usr/bin/env ruby

require 'optparse'
require 'dotenv'

Dotenv.load('config/env.sh')

if not Dir.exists? 'data'
  `command -v cfssl || brew install cfssl`
  `./generate/hub-dev-pki.sh`
end

COMMON = <<~COMMON
    ### APPS
    export METADATA_TRUST_STORE=#{`base64 data/pki/metadata.ts`}
    export METADATA_TRUST_STORE_PASSWORD=marshmallow
  COMMON

MSA = <<~MSA
    ### MSA
    export HUB_TRUST_STORE=#{`base64 data/pki/hub.ts`}
    export MSA_SIGNING_KEY_PRIMARY=#{`base64 data/pki/sample_rp_msa_signing_primary.pk8`}
    export MSA_SIGNING_CERT_PRIMARY=#{`base64 data/pki/sample_rp_msa_signing_primary.crt`}
    export MSA_SIGNING_KEY_SECONDARY=#{`base64 data/pki/sample_rp_msa_signing_secondary.pk8`}
    export MSA_SIGNING_CERT_SECONDARY=#{`base64 data/pki/sample_rp_msa_signing_secondary.crt`}
    export MSA_ENCRYPTION_KEY_PRIMARY=#{`base64 data/pki/sample_rp_msa_encryption_primary.pk8`}
    export MSA_ENCRYPTION_CERT_PRIMARY=#{`base64 data/pki/sample_rp_msa_encryption_primary.crt`}
  MSA

VSP = <<~VSP
    ### VSP
    export MSA_METADATA_URL=http://localhost:#{ENV['TEST_RP_MSA_PORT']}/matching-service/SAML2/metadata
    export MSA_ENTITY_ID=http://dev-rp-ms.local/SAML2/MD
    export SERVICE_ENTITY_IDS='["http://dev-rp.local/SAML2/MD"]'
    export VERIFY_ENVIRONMENT=COMPLIANCE_TOOL
    export SAML_SIGNING_KEY=#{`base64 data/pki/sample_rp_signing_primary.pk8`}
    export SAML_PRIMARY_ENCRYPTION_KEY=#{`base64 data/pki/sample_rp_encryption_primary.pk8`}

  VSP

IDP = <<~IDP
    ### IDP
    export IDP_SIGNING_PRIVATE_KEY=#{`base64 data/pki/stub_idp_signing_primary.pk8`}
    export IDP_SIGNING_CERT=#{`base64 data/pki/stub_idp_signing_primary.crt`}
    export HUB_ENTITY_ID=https://dev-hub.local
    export STUB_IDPS_FILE_PATH="../verify-local-startup/configuration/idps/stub-idps.yml"
  IDP

applications = {
    MSA: MSA,
    VSP: VSP,
    IDP: IDP
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
  f.puts(File.read('config/env.sh'))
  f.puts COMMON
  for app in apps
    f.puts applications[app]
  end
}

puts "Wrote environment to #{file}"