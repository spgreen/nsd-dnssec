FROM alpine:3.22.0
LABEL org.opencontainers.image.authors="Simon Green <simonpetergreen@singaren.net.sg>"

LABEL description="Simple DNS authoritative server with DNSSEC support" \
      maintainer="Simon Green <simonpetergreen@singaren.net.sg>"

ARG NSD_VERSION=4.14.0

#-----BEGIN PGP PUBLIC KEY BLOCK-----
#Comment: F8CB 0EFA A130 D9A5 EDC0  429B 7677 5760 1626 5A20
#Comment: Jannik Peters <jannik@nlnetlabs.nl>
ARG GPG_SHORTID="0x7677576016265A20"
ARG GPG_FINGERPRINT="F8CB 0EFA A130 D9A5 EDC0  429B 7677 5760 1626 5A20"
ARG SHA256_HASH="5d60e344002a9cc609ab71951a3cdb906314999e42f2a269044f27259ac2f12e"

ENV UID=991 GID=991

RUN apk add --no-cache --virtual build-dependencies \
      gnupg \
      build-base \
      libevent-dev \
      openssl-dev \
      ca-certificates \
 && apk add --no-cache \
      ldns \
      ldns-tools \
      libevent \
      protobuf-c-dev \
      fstrm-dev \
      openssl \
      tini \
 && cd /tmp \
 && wget -q https://www.nlnetlabs.nl/downloads/nsd/nsd-${NSD_VERSION}.tar.gz \
 && wget -q https://www.nlnetlabs.nl/downloads/nsd/nsd-${NSD_VERSION}.tar.gz.asc \
 && echo "Verifying both integrity and authenticity of nsd-${NSD_VERSION}.tar.gz..." \
 && CHECKSUM=$(sha256sum nsd-${NSD_VERSION}.tar.gz | awk '{print $1}') \
 && if [ "${CHECKSUM}" != "${SHA256_HASH}" ]; then echo "ERROR: Checksum does not match!" && exit 1; fi \
&& ( \
    gpg --keyserver hkps://keys.openpgp.org --recv-keys ${GPG_SHORTID} \
    ) \
 && FINGERPRINT="$(LANG=C gpg --verify nsd-${NSD_VERSION}.tar.gz.asc nsd-${NSD_VERSION}.tar.gz 2>&1 \
  | sed -n "s#Primary key fingerprint: \(.*\)#\1#p")" \
 && if [ -z "${FINGERPRINT}" ]; then echo "ERROR: Invalid GPG signature!" && exit 1; fi \
 && if [ "${FINGERPRINT}" != "${GPG_FINGERPRINT}" ]; then echo "ERROR: Wrong GPG fingerprint!" && exit 1; fi \
 && echo "All seems good, now unpacking nsd-${NSD_VERSION}.tar.gz..." \
 && tar xzf nsd-${NSD_VERSION}.tar.gz && cd nsd-${NSD_VERSION} \
 && ./configure \
    CFLAGS="-O2 -flto -fPIE -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=2 -fstack-protector-strong -Wformat -Werror=format-security" \
    LDFLAGS="-Wl,-z,now -Wl,-z,relro" \
 && make && make install \
 && apk del build-dependencies \
 && rm -rf /var/cache/apk/* /tmp/* /root/.gnupg

RUN adduser --disabled-password --uid 991 nsd-user


COPY bin /usr/local/bin
VOLUME /zones /etc/nsd /var/db/nsd
EXPOSE 53 53/udp
CMD ["run.sh"]
