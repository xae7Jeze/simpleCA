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

BASEDIR="${HOME}"
CANAME_RE='^[a-zA-Z_][a-zA-Z0-9_]{0,100}$'
DIGEST="sha256"
KEYCRYPTALGO="aes256"
RSA_KEY_LENGTH="4096"
DAYS="3650"

if echo "${0}" | fgrep -q / ; then
  MYDIR=${0%/*}
else
  MYDIR="$(which "${0}" || echo .)"
  MYDIR=${MYDIR%/*}
fi
MYDIR="$(cd "${MYDIR}" && pwd -P)"

SIGN_SH_SRC="${MYDIR}/sign.sh"

USAGE() {
  cat 1>&2 <<-_
	Usage: ${ME} [ -d <message_digest> -l <rsa_key_length> -c <algo_to_encrypt_pkey> -t <days> -b <basedir> ] -n <ca_name> -s <ca_subject>
	Usage: ${ME} -h
	Defaults:
	-b -> ${HOME} (must exist)
	-c -> aes256
	-d -> sha256
	-l -> 4096 (Must be >= 2048)
	-n -> NODEFAULT (must meet the regex "${CANAME_RE}")
	-s -> NODEFAULT (Must be formatted as expected by openssl req '-subj' arg)
	-t -> 3650 (Time in days certificate is valid)
  
  Creates CA-Structur in '${BASEDIR}/<ca_name>':
    sign.sh
    CA/
      <ca_name>.crt (CA-Certificate)
      <ca_name>.key (CA Private Key. Only RSA for now)
    certs/
    incoming/
    reqs/
	
	Version: $V
	
	_
}

CANAME=""
CASUBJECT=""

while getopts b:c:d:l:n:s:t:h opt;do
  case $opt in 
    b) BASEDIR=${OPTARG};;
    c) KEYCRYPTALGO=${OPTARG};;
    d) DIGEST=${OPTARG};;
    l) RSA_KEY_LENGTH=${OPTARG};;
    n) CANAME=${OPTARG};;
    s) CASUBJECT=${OPTARG};;
    t) DAYS=${OPTARG};;
    h) USAGE;exit 0 ;;
    *) USAGE;exit 1 ;;
  esac
done

if ! [ -f "${SIGN_SH_SRC}" ]; then
  echo "${ME}: ERROR: Could't find sign.sh in '${MYDIR}'" 1>&2
  exit 1
fi

if echo $DAYS | grep -q '[^0-9]' || [ $DAYS -lt 1 ] ; then
  echo "${ME}: ERROR: Invalid duration of validity" 1>&2
  exit 1
fi

if echo "${RSA_KEY_LENGTH}" | grep -q '[^0-9]' || [ "${RSA_KEY_LENGTH}" -lt 2048 ] ; then
  echo "${ME}: ERROR: Invalid keylength" 1>&2
  exit 1
fi

if ! [ -d "${BASEDIR}" ] ; then
  echo "${ME}: ERROR: Basedir doesn't exist" 1>&2
  exit 1
fi

if [ -z "${CASUBJECT}" ] ; then
  echo "${ME}: ERROR: Missing CA-Subject" 1>&2
  exit 1
fi

if ! echo "${CANAME}" | grep -Eq "${CANAME_RE}" ; then
  echo "${ME}: ERROR: Invalid CA-Name" 1>&2
  exit 1
fi

if ! openssl dgst "-${DIGEST}" > /dev/null 2>&1 < /dev/null; then
  echo "${ME}: ERROR: Invalid digest. Can't proceed" 1>&2
  exit 1
fi

CADIR="${BASEDIR}/${CANAME}"
SIGN_SH="${CADIR}/sign.sh"
CACRT="${CADIR}/CA/${CANAME}.crt"
CAKEY="${CADIR}/CA/${CANAME}.key"
if [ -d "${BASEDIR}/${CANAME}" ] ; then
  echo "${ME}: ERROR: Directory for CA '${BASEDIR}/${CANAME}' already exists. Exiting" 1>&2
  exit 1
fi

mkdir "${CADIR}"
mkdir -p "${CADIR}/CA" "${CADIR}/reqs" "${CADIR}/certs" "${CADIR}/incoming"
cp -i "${SIGN_SH_SRC}" "${SIGN_SH}"
chmod 700 "${SIGN_SH}"
set -C
for i in 1 2 3; do 
  KEY=$(openssl genpkey -algorithm RSA "-${KEYCRYPTALGO}" -pkeyopt "rsa_keygen_bits:${RSA_KEY_LENGTH}" 2>/dev/null) && break
  echo "${ME}: ERROR: passphrase to short or didn't match. Try again when prompted" 1>&2
done
if [ -z "${KEY}" ]; then
  echo "${ME}: ERROR: Generationg private key failed" 1>&2
	exit 1
fi
cat > "${CAKEY}" <<_
$KEY
_
unset KEY
for i in 1 2 3; do 
  CRT=$(openssl req -x509 -new -key "${CAKEY}" "-${DIGEST}" -days "${DAYS}" -subj "$CASUBJECT" 2>/dev/null) && break
  echo "${ME}: ERROR: Passphrases didn't match. Try again" 1>&2
done
if [ -z "${CRT}" ]; then
	rm -f "${CAKEY}"
  echo "${ME}: ERROR: Generating certificate failed" 1>&2
	exit 1
fi
cat > "${CACRT}" <<_
$CRT
_
unset CRT
set +C
echo "${ME}: SUCCESS: CA created in ${CADIR}"
