# Local startup

Repository with useful scripts for creating PKI, building and starting Verify apps

## Before you start

You'll need to install [cfssl](https://github.com/cloudflare/cfssl) which is used to generate the PKI.

## Generate PKI

`verify-local-startup` can be used to generate an entire PKI federation. Run `./generate/hub-dev-pki.sh` to create the required keys, certificates, federation config data, trust anchor and trust stores in `/data`.

## Create environment for running app locally

`generate-env.rb` can generate a `local.env` file for running Verify apps locally. The script takes a path to output the generated .env file to. It also, optionally, takes which apps (MSA or VSP) need variables added to the .env file.

### Example
```
ruby generate-env.rb -f ../verify-matching-service-adapter/local.env
```

This will add variables for all apps to the generated file. To add just the MSA related variables, i.e. excluding the VSP ones, add the argument `-a msa`.

## Run Verify locally
To run Verify locally, ensure all the following repositories are cloned as siblings to `verify-local-startup` (see `apps.yml` and `repos.yml`):
* verify-hub
* verify-frontend
* verify-test-rp
* verify-stub-idp
* verify-matching-service-adapter

To run the applications in Docker with the generated PKI, run:
```
./startup.sh
```
To run the applications but skip rebuilding images:
```
./startup.sh skip-build
```

## Trying the journey locally
To debug an issue or to manually test the journey, you need to start the SOCKS proxy service and connect a browser. To start the service, run:
```
docker-compose -f socks-proxy.yml up -d
```
You can then configure your browser to use `localhost:1080` as the SOCKS proxy server. To enable the SOCKS proxy in Firefox:
### Firefox
* open `about:config`
* set `network.proxy.socks` to `localhost`
* set `network.proxy.socks_port` to `1080`

### Chrome
* start Chrome with `/path/to/Chrome -proxy-server="socks5://localhost:1080"`
* On Mac OSX, `path/to/Chrome` is typically `/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome`

This will tunnel all your browser activity through the Docker network, including resolving Docker URLs such as `http://test-rp/test-rp`. You can still access the wider internet via the SOCKS proxy so the proxy server and browser config _can_ be left running.

## Support and raising issues

If you think you have discovered a security issue in this code please email [disclosure@digital.cabinet-office.gov.uk](mailto:disclosure@digital.cabinet-office.gov.uk) with details.

For non-security related bugs and feature requests please [raise an issue](https://github.com/alphagov/verify-service-provider/issues/new) in the GitHub issue tracker.

## Licence

[MIT Licence](LICENCE)

This code is provided for informational purposes only and is not yet intended for use outside GOV.UK Verify
