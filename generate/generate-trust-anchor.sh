#!/usr/bin/env bash

cd $(dirname "${BASH_SOURCE[0]}")

TRUST_ANCHOR_IMAGE=govukverify/trust-anchor
pushd ../data > /dev/null
  docker run -v $(pwd):/tmp:ro $TRUST_ANCHOR_IMAGE import "$COUNTRY_METADATA_URI" \
    /tmp/pki/stub_idp_signing_primary.crt \
    /tmp/ca-certificates/dev-idp-ca.pem.test \
    /tmp/ca-certificates/dev-root-ca.pem.test > trust-anchor.jwk

  docker run -v $(pwd):/tmp:ro $TRUST_ANCHOR_IMAGE sign-with-file \
    --key /tmp/pki/metadata_signing_a.pk8 \
    --cert /tmp/pki/metadata_signing_a.crt \
    /tmp/trust-anchor.jwk > metadata/trust-anchor
popd > /dev/null

