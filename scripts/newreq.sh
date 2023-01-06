#!/bin/bash
#
V=20230106.0

set -e -u

PATH="/bin:/usr/bin:/sbin:/usr/sbin"
LC_ALL=C
LANG=C
ME=${0##*/}
umask 077


CN_RE='([a-z0-9]|[a-z0-9][a-z0-9.-]{0,500}[a-z0-9])\.[a-z]{2,64}'

DIGEST="sha256"
KEYCRYPTALGO="aes256"
RSA_KEY_LENGTH="4096"
OUTDIR=""
SUBJECT=""
CN=""
S_ALTNAME=""
D=$(date +"%Y%m%d")


USAGE() {
  cat <<-_
		Usage: ${ME} [ -d <message_digest> -l <rsa_key_length> -c <algo_to_encrypt_pkey> -a <alt_names>] -s <cert_subject> -o <basic_output_directory>
		Defaults:
		  -a -> DNS:<common_name>,email:<copied_from_subject_if_any>
		  -c -> ${KEYCRYPTALGO} (Set to 'NONE', if you don't want to crypt private key)
		  -d -> ${DIGEST}
		  -l -> ${RSA_KEY_LENGTH} (Must be >= 2048)
		  -o -> NODEFAULT (must exist)
		  -s -> NODEFAULT (Must be formatted as expected by openssl req '-subj' arg, CN is mandatory and must be valid FQDN)
  
		  Outputs request and private key to '<output_directory>/<common_name>/<YYYYMMDD>/<common_name>.csr,<common_name>.key'
	
		  Version: $V
	
	_
}

while getopts a:c:d:l:o:s: opt;do
  case $opt in
    a) S_ALTNAME=${OPTARG};;
    c) KEYCRYPTALGO=${OPTARG};;
    d) DIGEST=${OPTARG};;
    l) RSA_KEY_LENGTH=${OPTARG};;
    o) OUTDIR=${OPTARG};;
    s) SUBJECT=${OPTARG};;
    *) USAGE;exit 1 ;;
  esac
done





if ! [ -d "${OUTDIR}" ] ; then
  USAGE
  exit 1
fi


CN="$(echo ${SUBJECT} | grep -iEo "/CN=${CN_RE}(/|$)" | tr -d "/" | sed 's|^CN=||' | tr A-Z a-z)"

if [ -z "${CN}" ] ; then
  echo "${ME}: Invalid  or missing CN. Can't proceed" 1>&2
  USAGE 1>&2
  exit 1
fi


if [ -z "${S_ALTNAME}" ]; then
  S_ALTNAME="DNS:${CN},email:copy"
fi

if [ "${KEYCRYPTALGO}" = "NONE" ] ; then
  CRYPTARG=""
else
  CRYPTARG="-${KEYCRYPTALGO}"
fi

OUT="${OUTDIR}/${CN}/${D}"
if [ -e "${OUT}" ] ; then
  echo "${ME}: Directory for key and req '${OUT}' already exists. Exiting" 1>&2
  exit 1
fi
mkdir -p "${OUT}"


set -C
openssl genpkey -algorithm RSA ${CRYPTARG} -pkeyopt "rsa_keygen_bits:${RSA_KEY_LENGTH}" > "${OUT}/${CN}.key"
openssl req -new -subj "${SUBJECT}" \
  -addext "subjectAltName =  ${S_ALTNAME}" \
  -key "${OUT}/${CN}.key" \
  > "${OUT}/${CN}.csr"
set +C
