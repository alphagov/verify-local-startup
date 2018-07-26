module PKI
  module_function
  def base64(file)
    Base64.encode64(File.read("#{File.dirname(__FILE__)}/../#{file}")).strip
  end

  def env
    {
      'METADATA_TRUSTSTORE' => base64("data/pki/metadata.ts"),
      'TRUSTSTORE_PASSWORD' => "marshmallow",
      'STUB_IDP_SIGNING_PRIVATE_KEY' => base64("data/pki/stub_idp_signing_primary.pk8"),
      'STUB_IDP_SIGNING_CERT' => base64("data/pki/stub_idp_signing_primary.crt"),
      'STUB_COUNTRY_SIGNING_PRIVATE_KEY' => base64("data/pki/stub_idp_signing_primary.pk8"), 
      'STUB_COUNTRY_SIGNING_CERT' => base64("data/pki/stub_idp_signing_primary.crt"),
    }
  end
end
