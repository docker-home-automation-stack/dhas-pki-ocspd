ARG BASE_IMAGE="debian"
ARG BASE_IMAGE_TAG="stretch"
FROM ${BASE_IMAGE}:${BASE_IMAGE_TAG}

# Arguments to instantiate as variables
ARG BASE_IMAGE
ARG BASE_IMAGE_TAG
ARG ARCH="amd64"
ARG PLATFORM="linux"
ARG TAG=""
ARG TAG_ROLLING=""
ARG BUILD_DATE=""
ARG IMAGE_VCS_REF=""
ARG VCS_REF=""
ARG FHEM_VERSION=""
ARG IMAGE_VERSION=""

ARG SVC_USER
ARG SVC_USER_ID
ARG SVC_GROUP
ARG SVC_GROUP_ID

ENV SVC_USER ${SVC_USER:-ocspd}
ENV SVC_USER_ID ${SVC_USER_ID:-42560}
ENV SVC_GROUP ${SVC_USER:-ocspd}
ENV SVC_GROUP_ID ${SVC_GROUP_ID:-42560}

ENV TERM xterm
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

COPY ./src/harden.sh ./src/entry.sh /
COPY ./src/libpki/ /usr/local/src/libpki/
COPY ./src/openca-ocspd/ /usr/local/src/openca-ocspd/
COPY ./src/config/ /ocspd.tmpl/

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
        apt-transport-https \
        apt-utils \
        locales \
    \
    && DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && /usr/sbin/update-locale LANG=en_US.UTF-8 \
    \
    && ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime \
    && echo "Europe/Berlin" > /etc/timezone \
    && DEBIAN_FRONTEND=noninteractive dpkg-reconfigure tzdata \
    \
    && DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
      build-essential \
      dumb-init \
      jq \
  		libicu-dev \
  		libldap-dev \
  		libxml2-dev \
  		libssl-dev \
    \
  	&& cd /usr/local/src/libpki/ && \
  	  ./configure && \
  	  make && \
  	  make install && \
      ls -la /usr/ && \
  	  ln -s /usr/lib64/libpki.so.88 /usr/lib/libpki.so.88 && \
  	  ln -s /usr/lib64/libpki.so.90 /usr/lib/libpki.so.90 && \
  	  cd / && \
  	  rm -rf cd /usr/local/src/libpki/ \
  	&& cd /usr/local/src/openca-ocsp/ && \
  	  ./configure --prefix=/usr/local/ocspd && \
      make && \
      make install && \
      cd / && \
      rm -rf /usr/local/ocspd/etc/ocspd/pki/token.d /usr/local/ocspd/etc/ocspd/ca.d /usr/local/ocspd/etc/ocspd/ocspd.xml && \
      ln -s /ocspd/token.d/ /usr/local/ocspd/etc/ocspd/pki/token.d && \
      ln -s /ocspd/ca.d/ /usr/local/ocspd/etc/ocspd/ca.d && \
      ln -s /ocspd/ocspd.xml /usr/local/ocspd/etc/ocspd/pki/ocspd.xml && \
      rm -rf /usr/local/src/openca-ocsp/ \
    \
    && apt-get purge -qqy \
        build-essential \
        cpanminus \
    && apt-get autoremove -qqy && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    \
    && /harden.sh \
    && /entry.sh init

WORKDIR /usr/local/ocspd
VOLUME /ocspd

EXPOSE 2560

ENTRYPOINT [ "/usr/bin/dumb-init", "--" ]
CMD [ "sh", "-c", "/entry.sh start /usr/local/ocspd/sbin/ocspd -stdout -c /usr/local/ocspd/etc/ocspd/ocspd.xml" ]
