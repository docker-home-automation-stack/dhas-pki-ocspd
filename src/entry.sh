#!/usr/bin/dumb-init /bin/sh
set -e

CMD="$1"; shift
SVC_HOME="/usr/local/ocspd"

if [ "${CMD}" = 'init' ] || [ "${CMD}" = 'start' ]; then
  echo "Setting permissions ..."
  [ ! -s /etc/passwd.orig ] && cp /etc/passwd /etc/passwd.orig
  [ ! -s /etc/shadow.orig ] && cp /etc/shadow /etc/shadow.orig
  [ ! -s /etc/group.orig ] && cp /etc/group /etc/group.orig
  cp -f /etc/passwd.orig /etc/passwd
  cp -f /etc/shadow.orig /etc/shadow
  cp -f /etc/group.orig /etc/group

  mkdir -p "${SVC_HOME}"
  addgroup -g ${SVC_GROUP_ID} ${SVC_GROUP}
  adduser -h "${SVC_HOME}" -s /bin/nologin -u ${SVC_USER_ID} -D -H -G ${SVC_GROUP} ${SVC_USER}
  chown ${SVC_USER}:${SVC_GROUP} "${SVC_HOME}"

  [ "${CMD}" = 'init' ] && exit 0
fi

if [ "${CMD}" = 'start' ]; then
  if [ ! -s "${SVC_HOME}/ocspd.xml" ]; then
    cp -r /ocspd.tmpl/* "${SVC_HOME}/"
  fi
  
  exec "$@"
  exit $?
fi

exit 1
