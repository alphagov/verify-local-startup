# Local startup

Repository with useful scripts for creating PKI, building and starting Verify apps

## Before you start

If you don't already have Go, you'll need to install it.

`brew install go`

Standard practice is to use one directory as your Go workspace and define an environment variable $GOPATH pointing to it. In that directory there should be sub directories *bin, src & pkg*. The $GOPATH/bin directory should be added to your $PATH.

You'll need to install [cfssl](https://github.com/cloudflare/cfssl) which is used to generate the PKI. In addition to this, you'll also need to install `cfssljson`, which is available from the same location.

## Generate PKI

`verify-local-startup` can be used to generate an entire PKI federation. Run `./generate/hub-dev-pki.sh` from the parent directory to create the required keys, certificates, federation config data and trust stores in `/data`; if you receive errors about incompatible libraries, use your Ruby version manager to use a newer version of Ruby and try again.

## Create environment for running app locally

`generate-env.rb` can generate a `local.env` file for running Verify apps locally. The script takes a path to output the generated .env file to. It also, optionally, takes which apps (MSA or VSP) need variables added to the .env file.

### Example
```
ruby generate-env.rb -f ../verify-matching-service-adapter/local.env
```

This will add variables for all apps to the generated file. To add just the MSA related variables, i.e. excluding the VSP ones, add the argument `-a msa`.

## Run Hub locally
To run hub locally, ensure all the following repositories are cloned as siblings to `verify-local-startup`:
* verify-hub
* verify-frontend
* verify-test-rp
* verify-stub-idp
* verify-matching-service-adapter
* verify-service-provider

`startup.sh` will then build and run the applications with the generated PKI. By using `generate-env.sh` with the configuration files in `/configuration`, each app can be restarted individually for development purposes.

## Support and raising issues

If you think you have discovered a security issue in this code please email [disclosure@digital.cabinet-office.gov.uk](mailto:disclosure@digital.cabinet-office.gov.uk) with details.

For non-security related bugs and feature requests please [raise an issue](https://github.com/alphagov/verify-service-provider/issues/new) in the GitHub issue tracker.

## Licence

[MIT Licence](LICENCE)

This code is provided for informational purposes only and is not yet intended for use outside GOV.UK Verify
