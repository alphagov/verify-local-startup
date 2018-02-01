#!/usr/bin/env bash

export METADATA_PORT=55500
export METADATA_URL=http://localhost:${METADATA_PORT}/dev.xml

export POLICY_PORT=50110
export CONFIG_PORT=50240
export SAML_PROXY_PORT=50220
export SAML_SOAP_PROXY_PORT=50160
export EVENT_SINK_PORT=51100
export SAML_ENGINE_PORT=50120
export TEST_RP_MSA_PORT=50210
export TEST_RP_PORT=50130
export VERIFY_FRONTEND_API_PORT=50190
export COMPLIANCE_TOOL_PORT=50270
export VSP_PORT=50400
export FRONTEND_PORT=50300
export STUB_IDP_PORT=50140

export FRONTEND_URI=http://localhost:${FRONTEND_PORT}
export STUB_IDP_URI=http://localhost:${STUB_IDP_PORT}
export TEST_RP_URI=http://localhost:${TEST_RP_PORT}

if [ "$VLS_TYPE" = "localhost" ]; then
    export MSA_URI=http://localhost:${TEST_RP_MSA_PORT}
else
    export MSA_URI=http://msa
fi

export HUB_CONNECTOR_ENTITY_ID="http://localhost:55000/local-connector/metadata.xml"
export COUNTRY_METADATA_URI="http://localhost:56002/ServiceMetadata"
export COUNTRY_EXPECTED_ENTITY_ID="http://localhost:56002/ServiceMetadata"
export EUROPEAN_IDENTITY_ENABLED=false
