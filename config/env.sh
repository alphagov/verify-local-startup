export METADATA_PORT=55000

export POLICY_PORT=50110
export CONFIG_PORT=50240
export SAML_PROXY_PORT=50220
export SAML_SOAP_PROXY_PORT=50160
export EVENT_SINK_PORT=51100
export SAML_ENGINE_PORT=50120
export TEST_RP_MSA_PORT=50210
export TEST_RP_PORT=50130
export STUB_IDP_PORT=50140
export VERIFY_FRONTEND_API_PORT=50190

# Frontend
export RP_DISPLAY_LOCALES=../verify-frontend-federation-config/configuration/display-locales/rps
export IDP_DISPLAY_LOCALES=../verify-frontend-federation-config/configuration/display-locales/idps
export IDP_RANKINGS_CONFIG=../verify-frontend-federation-config/configuration/idp_rankings.yml
export RULES_DIRECTORY=../verify-frontend-federation-config/configuration/idp-rules

# To get the logos working correctly one would need to symlink their directories
# in verify-frontend-federation-config to a public folder in verify-frontend.
# If you don't mind logos not displaying correctly they don't need to be correct:
export LOGO_DIRECTORY=/dev/null
export WHITE_LOGO_DIRECTORY=/dev/null

# To get all cycle 3 attributes that are available in prod (acceptance tests are testing against real rps like defra),
# we are setting up symlinks to the cycle 3 directories in verify-frontend-federation-config. If this is not done,
# some cycle 3 acceptance tests will fail locally.
export CYCLE_3_DISPLAY_LOCALES=../verify-frontend-federation-config/configuration/display-locales/cycle_3
export CYCLE_THREE_ATTRIBUTES_DIRECTORY=../verify-frontend-federation-config/configuration/cycle-three-attributes

# We use the real ZenDesk test instance since this is what we did before we migrated to verify-frontend.
# This is an external dependency required for the tests to pass, so reconsider at some point.
export ZENDESK_URL=https://gdshelp1433843179.zendesk.com/api/v2
export ZENDESK_USERNAME=idasupport@digital.cabinet-office.gov.uk
export ZENDESK_TOKEN=l4Jx6LCSAMtuGzoTmx63TLvlrun2pBaCNCm56pOi

export FRONTEND_URI=http://localhost:50300
