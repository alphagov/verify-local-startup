# This Dockerfile is for generating the Metadata
# and environment used for running the HUB.
FROM ghcr.io/alphagov/verify/golang:1.15.5-alpine3.12 as golang

RUN apk --no-cache upgrade && \
    apk add --no-cache build-base git &&\
    go get -u github.com/cloudflare/cfssl/cmd/...

FROM ghcr.io/alphagov/verify/ruby:2.7.2-alpine3.12

RUN apk --no-cache upgrade && \
    apk add --no-cache build-base ncurses bash git openssl openjdk11 curl

COPY --from=golang /go/bin /go/bin
ENV PATH="/go/bin:${PATH}"

ADD Gemfile Gemfile
ADD Gemfile.lock Gemfile.lock

RUN bundle &&\
    curl --silent -O https://shibboleth.net/downloads/tools/xmlsectool/latest/xmlsectool-3.0.0-bin.zip &&\
    unzip xmlsectool-3.0.0-bin.zip

ENV XMLSECTOOL="/xmlsectool-3.0.0/xmlsectool.sh"
ENV JAVA_HOME=/usr/lib/jvm/default-jvm/jre

COPY config/bashrc /root/.bashrc

RUN chmod +x /root/.bashrc

# We use this to set ownership permissions on the
# generated data directory and env files
ARG USER_ID=1000
ARG GROUP_ID=1000
RUN addgroup -g $GROUP_ID staff
RUN adduser -u $USER_ID -G staff -D verify
ENV USER_ID ${USER_ID}
ENV GROUP_ID ${GROUP_ID}

WORKDIR /verify-local-startup
ENTRYPOINT ["/bin/bash", "-c"]
