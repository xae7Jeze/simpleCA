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
  echo "${ME}: Won't run with UID 0 (root). Exiting" 1>&2
  exit 1
fi

CN_RE='([a-z0-9]|[a-z0-9][a-z0-9.-]{0,500}[a-z0-9])\.[a-z]{2,64}'

DIGEST="sha256"
KEYCRYPTALGO="aes256"
RSA_KEY_LENGTH="4096"
BASEOUTPUTDIR=""
SUBJECT=""
CN=""
S_ALTNAME=""
D=$(date "+%Y%m%d%H%M%S")

USAGE() {
  cat 1>&2 <<-_
		Usage: ${ME} [ -d <message_digest> -l <rsa_key_length> -c <algo_to_encrypt_pkey> -a <alt_names> ] -s <cert_subject> -o <basic_output_directory>
		Usage: ${ME} -h
		Defaults:
		  -a -> DNS:<common_name>,email:<copied_from_subject_if_any>
		  -c -> aes256 (Set to 'NONE', if you don't want to encrypt private key)
		  -d -> sha256
		  -l -> 4096 (Must be >= 2048)
		  -o -> NODEFAULT (must exist)
		  -s -> NODEFAULT (Must be formatted as expected by openssl req '-subj' arg, CN is mandatory and must be valid FQDN)
  
		  Outputs request and private key to '<output_directory>/<common_name>/<YYYYmmddHHMMSS>/<common_name>.csr,<common_name>.key'
	
		  Version: $V
	
	_
}

while getopts a:c:d:l:o:s:h opt;do
  case $opt in
    a) S_ALTNAME=${OPTARG};;
    c) KEYCRYPTALGO=${OPTARG};;
    d) DIGEST=${OPTARG};;
    h) USAGE; exit 0 ;;
    l) RSA_KEY_LENGTH=${OPTARG};;
    o) BASEOUTPUTDIR=${OPTARG};;
    s) SUBJECT=${OPTARG};;
    *) USAGE; exit 1 ;;
  esac
done

if ! [ -d "${BASEOUTPUTDIR}" ] ; then
  echo "${ME}: ERROR: Basic output directory doesn't exist." 1>&2
  USAGE
  exit 1
fi

CN="$(echo ${SUBJECT} | grep -iEo "/CN=${CN_RE}(/|$)" | tr -d "/" | cut -d= -f2 | tr A-Z a-z)"

if [ -z "${CN}" ] ; then
  echo "${ME}: ERROR: Invalid or missing CommonName." 1>&2
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

OUTDIR="${BASEOUTPUTDIR}/${CN}/${D}"
if [ -e "${OUTDIR}" ] ; then
  echo "${ME}: ERROR: Output-Directory already exists." 1>&2
  exit 1
fi
mkdir -p "${OUTDIR}"


set -C
if ! openssl genpkey -algorithm RSA ${CRYPTARG} -pkeyopt "rsa_keygen_bits:${RSA_KEY_LENGTH}" > "${OUTDIR}/${CN}.key"; then
  echo "${ME}: ERROR: Creating PRIVATE KEY failed" 1>&2
	rm -f "${OUTDIR}/${CN}.key"
  exit 1
fi
if ! openssl req -new -subj "${SUBJECT}" \
  -addext "subjectAltName =  ${S_ALTNAME}" \
  -key "${OUTDIR}/${CN}.key" \
  > "${OUTDIR}/${CN}.csr" ; then
  echo "${ME}: ERROR: Creating CSR failed" 1>&2
	rm -f "${OUTDIR}/${CN}.key" "${OUTDIR}/${CN}.csr" 
  exit 1
fi
set +C

echo "${ME}: SUCCESS: New request generated in '${OUTDIR}'"
exit 0
