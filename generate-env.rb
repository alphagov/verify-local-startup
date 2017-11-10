#!/usr/bin/env ruby

require 'optparse'
require 'dotenv'

Dotenv.load('config/env.sh')

MSA = <<~MSA
    ### MSA
    export HUB_TRUST_STORE=#{`base64 data/pki/hub.ts`}
    export METADATA_TRUST_STORE=#{`base64 data/pki/metadata.ts`}
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

applications = {
    MSA: MSA,
    VSP: VSP
}

apps = applications.keys
file = 'local.env'
OptionParser.new do |opts|
  opts.banner = "Usage: generate-env.rb [-a/apps]"

  opts.on("-f file", "--f file",) do |f|
    puts f
    file = f
  end

  opts.on("--apps a1,a2,a3", Array) do |a|
    apps = a.map { |e| e.upcase.to_sym }
  end
end.parse!

if not Dir.exists? 'data'
  `command -v cfssl || brew install cfssl`
  `./generate/hub-dev-pki.sh`
end

unless apps.all? {|a| applications.has_key? a}
  puts "No configuration exists for apps: #{apps}"
  exit 1
end

open(file, 'w') { |f|
  f.puts(File.read('config/env.sh'))
  for app in apps
    f.puts applications[app]
  end
}

puts "Wrote environment to #{file}"