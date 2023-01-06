#!/bin/bash
#
V=20230106.1

set -e -u

PATH="/bin:/usr/bin:/sbin:/usr/sbin"
LC_ALL=C
LANG=C
ME=${0##*/}
umask 077


if echo "${0}" | fgrep -q / ; then
  MYDIR=${0%/*}
else
  MYDIR="$(which "${0}" || echo .)"
  MYDIR=${MYDIR%/*}
fi
MYDIR="$(cd "${MYDIR}" && pwd -P)"
CANAME=${MYDIR##*/}

D=$(date "+%Y%m%d")
CADIR=${MYDIR}
CACRT="${CADIR}/CA/${CANAME}.crt"
CAKEY="${CADIR}/CA/${CANAME}.key"
CASERIAL="${CADIR}/CA/serial.txt"
DIGEST="sha256"
DAYS=365
INFILE=""

USAGE() {
  cat <<-_
	Usage: ${ME} [ -d <message_digest> -t <days>] -i <requestfile>
	Defaults:
	-d -> ${DIGEST}
	-i -> NODEFAULT
	-t -> ${DAYS} (Time in days certificate is valid)
	
	Version: $V     
	
	_
}

while getopts d:i:t: opt;do
  case $opt in 
    d) DIGEST=${OPTARG};;
    i) INFILE=${OPTARG};;
    t) DAYS=${OPTARG};;
    *) USAGE;exit 1 ;;
  esac
done

if ! [ -f "${CACRT}" -a -f "${CAKEY}" ]; then
  echo "${ME}: Missing '${CACRT}' and/or '${CAKEY}' in '${CADIR}/CA/'" 1>&2 
  echo "${ME}: Am I in the top level of CA-Directory-Structure?" 1>&2 
  echo "${ME}: Exiting" 1>&2 
  exit 1
fi

if echo $DAYS | grep -q '[^0-9]' || [ $DAYS -lt 1 ] ; then
  USAGE
  exit 1
fi


if ! [ -f "${INFILE}" ] ; then
  USAGE
  exit 1
fi

CN="$(openssl req -in "${INFILE}" -noout -subject | grep -E -o 'CN *= *[0-9a-zA-Z][0-9a-zA-Z.-]*[[0-9a-zA-Z]' | tr 'A-Z' 'a-z' | cut -d= -f2 | tr -dc '[0-9a-z.-]')"

if ! echo "${CN}" | egrep -qi '^[0-9a-z][0-9a-z.-]*[0-9a-z]$'; then
  echo "${ME}: Invalid CN (must be valid FQDN)" 1>&2
  exit 1
fi

if ! openssl dgst "-${DIGEST}" > /dev/null 2>&1 < /dev/null; then
  echo "${ME}: Invalid digest. Can't proceed" 1>&2
  exit 1
fi
 

REQDIR="${CADIR}/reqs/${D}/${CN}"
CRTDIR="${CADIR}/certs/${D}/${CN}"
EXTFILE="${REQDIR}/${CN}.ext"
REQFILE="${REQDIR}/${CN}.csr"
CRTFILE="${CRTDIR}/${CN}.crt"

mkdir -p "${CRTDIR}" "${REQDIR}"
set -C

test -e "${REQFILE}" || cp -i "${INFILE}" "${REQFILE}"

if ! test "$(sha256sum < "${INFILE}")" = "$(sha256sum < "${REQFILE}")"; then
  echo "${ME}: Copy input file to request dir failed" 1>&2
  exit 1
fi

cat > "${EXTFILE}" <<_
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
_

set +C
{
d=1;e=1;i=1
ALTNAMES=$(openssl req -in "${REQFILE}" -text \
  | fgrep  -A 200 ' X509v3 Subject Alternative Name:' \
  | grep -E '^[[:space:]]*(DNS|email|IP Address):[^,]+' \
  | tr -d " \t" | tr "," "\n" | sort)
while read l; do
  case "$l" in 
    DNS:*) item="DNS"; echo $l | sed "s/^${item}:\(.*\)$/${item}.${d} = \1/"; d=$((d+1)) ;;
    email:*) item="email"; echo $l | sed "s/^${item}:\(.*\)$/${item}.${e} = \1/"; e=$((e+1)) ;;
    IPAddress:*) item="IPAddress"; echo $l | sed "s/^${item}:\(.*\)$/IP.${i} = \1/"; i=$((1+1)) ;;
  esac
done <<_
$ALTNAMES
_
echo email.${e} = copy
} >> "${EXTFILE}"

set -C
openssl x509 -req -in "${REQFILE}" -CA "${CACRT}" -CAkey "${CAKEY}" -CAcreateserial -CAserial "${CASERIAL}" "-${DIGEST}" -extfile "${EXTFILE}" > "${CRTFILE}" -days "${DAYS}"
