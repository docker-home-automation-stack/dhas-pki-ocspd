FROM alpine

ARG SVC_USER
ARG SVC_USER_ID
ARG SVC_GROUP
ARG SVC_GROUP_ID

ENV SVC_USER ${SVC_USER:-ocspd}
ENV SVC_USER_ID ${SVC_USER_ID:-42560}
ENV SVC_GROUP ${SVC_USER:-ocspd}
ENV SVC_GROUP_ID ${SVC_GROUP_ID:-42560}

COPY ./src/harden.sh ./src/entry.sh /
COPY ./src/libpki/ /usr/local/src/libpki/
COPY ./src/openca-ocspd/ /usr/local/src/openca-ocspd/
COPY ./src/config/ /ocspd.tmpl/

RUN apk add --no-cache \
      build-base \
      dumb-init \
  		libicu-dev \
  		libldap-dev \
  		libxml2-dev \
  		libssl-dev \
    \
  	&& cd /usr/local/src/libpki/ && \
  	  ./configure && \
  	  make && \
  	  make install && \
      ls -la /usr/ &&
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
    && apk del \
      build-base \
    \
    && /harden.sh \
    && /entry.sh init

WORKDIR /usr/local/ocspd
VOLUME /pki
VOLUME /ocspd

EXPOSE 2560

ENTRYPOINT [ "/usr/bin/dumb-init", "--" ]
CMD [ "sh", "-c", "/entry.sh start /usr/local/ocspd/sbin/ocspd -stdout -c /usr/local/ocspd/etc/ocspd/ocspd.xml" ]
