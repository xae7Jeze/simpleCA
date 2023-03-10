#!/bin/bash
#
# Author: github.com/xae7Jeze
#
V=20230107.0

set -e -u

PATH="/bin:/usr/bin:/sbin:/usr/sbin"
LC_ALL=C
LANG=C
ME=${0##*/}
umask 077

MYUID=$(id -u)
if [ ${MYUID:-0} -eq 0 ]; then
  echo "${ME}: ERROR: Won't run with UID 0 (root). Exiting" 1>&2
  exit 1
fi

if echo "${0}" | fgrep -q / ; then
  MYDIR=${0%/*}
else
  MYDIR="$(which "${0}" || echo .)"
  MYDIR=${MYDIR%/*}
fi
MYDIR="$(cd "${MYDIR}" && pwd -P)"
CANAME=${MYDIR##*/}

D=$(date "+%Y%m%d%H%M%S")
CADIR="${MYDIR}"
CACRT="${CADIR}/CA/${CANAME}.crt"
CAKEY="${CADIR}/CA/${CANAME}.key"
DIGEST="sha256"
DAYS=365
INFILE=""

USAGE() {
  cat 1>&2 <<-_
	Usage: ${ME} [ -d <message_digest> -t <days>] -i <requestfile>
	Usage: ${ME} -h 
	Defaults:
	  -d -> sha256
	  -i -> NODEFAULT
	  -t -> ${DAYS} (Time in days certificate is valid)
	
    Output goes to ${CADIR}/certs/<common_name>/<YYYYmmddHHMMSS>
	
	  Version: $V
	
	_
}

while getopts d:i:t:h opt;do
  case $opt in 
    d) DIGEST=${OPTARG};;
    h) USAGE; exit 0 ;;
    i) INFILE=${OPTARG};;
    t) DAYS=${OPTARG};;
    *) USAGE; exit 1 ;;
  esac
done

if ! [ -f "${CACRT}" -a -f "${CAKEY}" ]; then
  echo "${ME}: ERROR: Missing '${CACRT}' and/or '${CAKEY}' in '${CADIR}/CA/'" 1>&2 
  echo "${ME}: ERROR: Am I in the top level of a CA-Directory-Structure?" 1>&2 
  echo "${ME}: ERROR: Exiting" 1>&2 
  exit 1
fi

if echo $DAYS | grep -q '[^0-9]' || [ $DAYS -lt 1 ] ; then
  echo "${ME}: ERROR: Invalid duration of validity" 1>&2
  exit 1
fi


if ! [ -f "${INFILE}" ] ; then
	echo "${ME}: ERROR: Opening input file failed" 1>&2
  exit 1
fi

CN="$(openssl req -in "${INFILE}" -noout -subject | grep -E -o 'CN *= *[0-9a-zA-Z][0-9a-zA-Z.-]*[[0-9a-zA-Z]' | tr 'A-Z' 'a-z' | cut -d= -f2 | tr -dc '[0-9a-z.-]')"

if ! echo "${CN}" | grep -Eqi '^[0-9a-z][0-9a-z.-]*[0-9a-z]$'; then
  echo "${ME}: ERROR: Invalid CN (must be valid FQDN)" 1>&2
  exit 1
fi

if ! openssl dgst "-${DIGEST}" > /dev/null 2>&1 < /dev/null; then
  echo "${ME}: ERROR: Invalid digest. Can't proceed" 1>&2
  exit 1
fi
 

REQDIR="${CADIR}/reqs/${CN}/${D}"
CRTDIR="${CADIR}/certs/${CN}/${D}"
EXTFILE="${REQDIR}/${CN}.ext"
REQFILE="${REQDIR}/${CN}.csr"
CRTFILE="${CRTDIR}/${CN}.crt"
CASERIAL="${CRTDIR}/${CN}.srl"

mkdir -p "${CRTDIR}" "${REQDIR}"

cp -i "${INFILE}" "${REQFILE}"

set -C
cat > "${EXTFILE}" <<_
authorityKeyIdentifier=keyid,issuer
subjectKeyIdentifier=hash
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
_

set +C

{
d=1;e=1;i=1;u=1
ALTNAMES=$(openssl req -in "${REQFILE}" -text \
  | fgrep  -A 200 ' X509v3 Subject Alternative Name:' \
  | grep -E '^[[:space:]]*(DNS|email|IP Address|URI):[^,]+' \
  | tr -d " \t" | tr "," "\n" | sort)
while read l; do
  case "$l" in 
    DNS:*) item="DNS"; echo $l | sed "s/^${item}:\(.*\)$/${item}.${d} = \1/"; d=$((d+1)) ;;
    email:*) item="email"; echo $l | sed "s/^${item}:\(.*\)$/${item}.${e} = \1/"; e=$((e+1)) ;;
    IPAddress:*) item="IPAddress"; echo $l | sed "s/^${item}:\(.*\)$/IP.${i} = \1/"; i=$((1+1)) ;;
    URI:*) item="URI"; echo $l | sed "s/^${item}:\(.*\)$/${item}.${d} = \1/"; u=$((d+1)) ;;
  esac
done <<_
$ALTNAMES
_
echo email.${e} = copy
} >> "${EXTFILE}"

set -C
if ! openssl x509 -req -in "${REQFILE}" -CA "${CACRT}" -CAkey "${CAKEY}" -CAcreateserial -CAserial "${CASERIAL}" "-${DIGEST}" -extfile "${EXTFILE}" > "${CRTFILE}" -days "${DAYS}"; then
	echo "${ME}: ERROR: Signing CSR failed" 1>&2
	rm -f "${CRTFILE}"
	exit 1
fi
set +C

echo "${ME}: SUCCESS: Wrote certificate to ${CRTFILE}"
exit 0
