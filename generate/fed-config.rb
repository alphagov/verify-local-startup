#!/usr/bin/env ruby

require 'yaml'

def inline_cert(cert)
  IO.readlines(cert).map(&:strip).reject(&:empty?)[1 ... -1].join
end

if ARGV.size < 5
  puts "Usage: metadata-sources.rb rp_signing rp_encryption msa_signing msa_encryption output_dir display_locale_dir"
  exit 1
end

rp_signing_cert = ARGV[0]
rp_encryption_cert = ARGV[1]
msa_signing_cert = ARGV[2]
msa_encryption_cert = ARGV[3]
output_dir = ARGV[4]
display_locales_dir = ARGV[5]

idps = {
  'stub-idp-one' => { 'enabled' => false },
  'stub-idp-two' => { 'useExactComparisonType' => false },
  'stub-idp-three' => {},
  'stub-idp-four' => {}
}

rps = {
  'dev-rp' => {
    'simpleId' => 'test-rp',
    'matchingProcess' => { 'cycle3AttributeName' => 'NationalInsuranceNumber' }
  },
  'dev-rp-no-eidas' => {
    'simpleId' => 'test-rp',
    'eidasEnabled' => false
  }
}

translations = {
  'test-rp' => {
    'translations' => [
      {
        'locale' => 'en',
        'name' => 'register for an identity profile',
        'rpName' => 'Test RP',
        'analyticsDescription' => 'TEST RP',
        'otherWaysDescription' => 'access TestRP',
        'otherWaysText' => '<p>Specific text to be provided by the RP.</p>',
        'tailoredText' => '<p>This is tailored text for TEST RP - from Config Service</p>',
        'taxonName' => 'Test RP'
      }
    ]
  }
}

countries = {
  'reference' => { 'simpleId' => 'ZZ' },
  'netherlands' => { 'simpleId' => 'NL' },
  'spain' => { 'simpleId' => 'ES', 'overriddenSsoUrl' => 'http://spain.country/sso-override' },
  'sweden' => { 'simpleId' => 'SE', 'enabled' => false },
}

Dir::mkdir(output_dir) unless Dir::exist?(output_dir)

Dir::chdir(output_dir) do
  ['idps', 'matching-services', 'transactions', 'countries'].each do |dir|
    Dir::mkdir(dir) unless Dir::exist?(dir)
  end

  Dir::chdir('idps') do
    idps.each do |idp, overrides|
      File.open("#{idp}.yml", 'w') do |f|
        f.write(YAML.dump({
            'entityId' => "http://#{idp}.local/SSO/POST",
            'simpleId' => idp,
            'enabled' => true,
            'supportedLevelsOfAssurance' => [ 'LEVEL_1', 'LEVEL_2' ],
            'useExactComparisonType' => true
          }.update(overrides)))
      end
    end
  end

  Dir::chdir('matching-services') do
    rps.each do |rp, _|
      File.open("#{rp}-ms.yml", 'w') do |f|
        msa_url = "#{ENV.fetch('MSA_URI')}"
        f.write(YAML.dump(
          'entityId' => "http://#{rp}-ms.local/SAML2/MD",
          'healthCheckEnabled' => true,
          'uri' => "#{msa_url}/matching-service/POST",
          'userAccountCreationUri' => "#{msa_url}/unknown-user-attribute-query",
          'signatureVerificationCertificates' => [ { 'x509' => inline_cert(msa_signing_cert) } ],
          'encryptionCertificate' => { 'x509' => inline_cert(msa_encryption_cert) }
        ))
      end
    end
  end

  Dir::chdir('transactions') do
    rps.each do |rp, overrides|
      File.open("#{rp}.yml", 'w') do |f|
        f.write(YAML.dump({
          'entityId' => "http://#{rp}.local/SAML2/MD",
          'simpleId' => rp,
          'assertionConsumerServices' => [
            { 'uri' => "#{ENV.fetch('TEST_RP_URI')}/test-rp/login", 'index' => 0, 'isDefault' => true }
          ],
          'levelsOfAssurance' => [ 'LEVEL_2' ],
          'matchingServiceEntityId' => "http://#{rp}-ms.local/SAML2/MD",
          'displayName' => 'Register for an identity profile',
          'otherWaysDescription' => 'access Dev RP',
          'serviceHomepage' => "http://#{rp}.local/home",
          'rpName' => 'Dev RP',
          'analyticsTransactionDescription' => 'DEV RP',
          'enabled' => true,
          'eidasEnabled' => true,
          'shouldHubSignResponseMessages' => true,
          'userAccountCreationAttributes' => [
            'FIRST_NAME',
            'FIRST_NAME_VERIFIED',
            'MIDDLE_NAME',
            'MIDDLE_NAME_VERIFIED',
            'SURNAME',
            'SURNAME_VERIFIED',
            'DATE_OF_BIRTH',
            'DATE_OF_BIRTH_VERIFIED',
            'CURRENT_ADDRESS',
            'CURRENT_ADDRESS_VERIFIED'
          ],
          'otherWaysToCompleteTransaction' => 'Do something else',
          'signatureVerificationCertificates' => [ { 'x509' => inline_cert(rp_signing_cert) } ],
          'encryptionCertificate' => { 'x509' => inline_cert(rp_encryption_cert) }
        }.update(overrides)))
      end
    end
  end

  Dir::chdir('countries') do
    countries.each do |country, overrides|
      File.open("#{country}.yml", 'w') do |f|
        f.write(YAML.dump({
          'entityId' => "http://#{country}.country/metadata",
          'simpleId' => 'AA',
          'enabled' => true
        }.update(overrides)))
      end
    end
  end
end

Dir::mkdir(display_locales_dir) unless Dir::exist?(display_locales_dir)

Dir::chdir(display_locales_dir) do
  Dir::mkdir('transactions') unless Dir::exist?('transactions')
  Dir::chdir('transactions') do
    translations.each do |rp, overrides|
      File.open("#{rp}.yml", 'w') do |f|
        f.write(YAML.dump({'simpleId' => rp}.update(overrides)))
      end
    end
  end
end
