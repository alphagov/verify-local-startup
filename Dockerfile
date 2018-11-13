FROM golang:1.11.0-alpine3.7 as golang

RUN apk --no-cache upgrade && \
    apk add --no-cache build-base git &&\
    go get -u github.com/cloudflare/cfssl/cmd/...

FROM ruby:2.5.1-alpine3.7

RUN apk --no-cache upgrade && \
    apk add --no-cache build-base ncurses bash git openssl openjdk8 curl

COPY --from=golang /go/bin /go/bin
ENV PATH="/go/bin:${PATH}"

ADD Gemfile Gemfile
ADD Gemfile.lock Gemfile.lock

RUN bundle &&\
    curl --silent -O https://shibboleth.net/downloads/tools/xmlsectool/latest/xmlsectool-2.0.0-bin.zip &&\
    unzip xmlsectool-2.0.0-bin.zip

ENV XMLSECTOOL="/xmlsectool-2.0.0/xmlsectool.sh"
ENV JAVA_HOME=/usr/lib/jvm/default-jvm/jre

WORKDIR /verify-local-startup
ENTRYPOINT ["/bin/bash", "-c"]
