module Urls
  module_function
  def env
    {
      "METADATA_URL" => "http://metadata/dev.xml",
      "POLICY_URL" => "http://policy",
      "CONFIG_URL" => "http://config",
      "SAML_PROXY_URL" => "http://saml-proxy",
      "SAML_SOAP_PROXY_URL" => "http://saml-soap-proxy",
      "EVENT_SINK_URL" => "http://stub-event-sink",
      "SAML_ENGINE_URL" => "http://saml-engine",
      "MSA_URL" => "http://msa",
      "RP_SERVICE_URL" => "http://rp-service",
      "STUB_IDP_URL" => "http://stub-idp",
      "VSP_URL" => "http://vsp",
      "FRONTEND_URL" => "http://frontend",
      "TEST_RP_URL" => "http://test-rp",
      "DB_URI" => "jdbc:postgresql://stub-idp-db:5432/postgres?user=postgres&password=password",
    }
  end
end
