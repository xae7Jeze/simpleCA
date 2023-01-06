#!/bin/bash
#
# Author: github.com/xae7Jeze
#
V=20230106.5

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

BASEDIR="${HOME}"
CANAME_RE='^[a-zA-Z_][a-zA-Z0-9_]{0,100}$'
DIGEST="sha256"
KEYCRYPTALGO="aes256"
RSA_KEY_LENGTH="4096"
DAYS="3650"

USAGE() {
  cat <<-_
	Usage: ${ME} [ -d <message_digest> -l <rsa_key_length> -c <algo_to_encrypt_pkey> -t <days> -b <basedir> ] -n <ca_name> -s <ca_subject>
	Defaults:
	-b -> ${BASEDIR} (must exist)
	-c -> ${KEYCRYPTALGO}
	-d -> ${DIGEST}
	-l -> ${RSA_KEY_LENGTH} (Must be >= 2048)
	-p -> print sign.sh to stdout
	-n -> NODEFAULT (must meet the regex "${CANAME_RE}")
	-s -> NODEFAULT (Must be formatted as expected by openssl req '-subj' arg)
	-t -> ${DAYS} (Time in days certificate is valid)
  
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


SIGN_SH_SRC="
IyEvYmluL2Jhc2gKIwojIEF1dGhvcjogZ2l0aHViLmNvbS94YWU3SmV6ZQojClY9MjAyMzAxMDYu
NgoKc2V0IC1lIC11CgpQQVRIPSIvYmluOi91c3IvYmluOi9zYmluOi91c3Ivc2JpbiIKTENfQUxM
PUMKTEFORz1DCk1FPSR7MCMjKi99CnVtYXNrIDA3NwoKTVlVSUQ9JChpZCAtdSkKaWYgWyAke01Z
VUlEOi0wfSAtZXEgMCBdOyB0aGVuCiAgZWNobyAiJHtNRX06IFdvbid0IHJ1biB3aXRoIFVJRCAw
IChyb290KS4gRXhpdGluZyIgMT4mMgogIGV4aXQgMQpmaQoKaWYgZWNobyAiJHswfSIgfCBmZ3Jl
cCAtcSAvIDsgdGhlbgogIE1ZRElSPSR7MCUvKn0KZWxzZQogIE1ZRElSPSIkKHdoaWNoICIkezB9
IiB8fCBlY2hvIC4pIgogIE1ZRElSPSR7TVlESVIlLyp9CmZpCk1ZRElSPSIkKGNkICIke01ZRElS
fSIgJiYgcHdkIC1QKSIKQ0FOQU1FPSR7TVlESVIjIyovfQoKRD0kKGRhdGUgIislWSVtJWQlSCVN
JVMiKQpDQURJUj0ke01ZRElSfQpDQUNSVD0iJHtDQURJUn0vQ0EvJHtDQU5BTUV9LmNydCIKQ0FL
RVk9IiR7Q0FESVJ9L0NBLyR7Q0FOQU1FfS5rZXkiCkRJR0VTVD0ic2hhMjU2IgpEQVlTPTM2NQpJ
TkZJTEU9IiIKClVTQUdFKCkgewogIGNhdCA8PC1fCglVc2FnZTogJHtNRX0gWyAtZCA8bWVzc2Fn
ZV9kaWdlc3Q+IC10IDxkYXlzPl0gLWkgPHJlcXVlc3RmaWxlPgoJRGVmYXVsdHM6CgkgIC1kIC0+
ICR7RElHRVNUfQoJICAtaSAtPiBOT0RFRkFVTFQKCSAgLXQgLT4gJHtEQVlTfSAoVGltZSBpbiBk
YXlzIGNlcnRpZmljYXRlIGlzIHZhbGlkKQoJCiAgICBPdXRwdXQgZ29lcyB0byAke0NBRElSfS9j
ZXJ0cy8ke0NOfS8ke0R9CgkKCSAgVmVyc2lvbjogJFYKCQoJXwp9Cgp3aGlsZSBnZXRvcHRzIGQ6
aTp0OiBvcHQ7ZG8KICBjYXNlICRvcHQgaW4gCiAgICBkKSBESUdFU1Q9JHtPUFRBUkd9OzsKICAg
IGkpIElORklMRT0ke09QVEFSR307OwogICAgdCkgREFZUz0ke09QVEFSR307OwogICAgKikgVVNB
R0U7ZXhpdCAxIDs7CiAgZXNhYwpkb25lCgppZiAhIFsgLWYgIiR7Q0FDUlR9IiAtYSAtZiAiJHtD
QUtFWX0iIF07IHRoZW4KICBlY2hvICIke01FfTogTWlzc2luZyAnJHtDQUNSVH0nIGFuZC9vciAn
JHtDQUtFWX0nIGluICcke0NBRElSfS9DQS8nIiAxPiYyIAogIGVjaG8gIiR7TUV9OiBBbSBJIGlu
IHRoZSB0b3AgbGV2ZWwgb2YgYSBDQS1EaXJlY3RvcnktU3RydWN0dXJlPyIgMT4mMiAKICBlY2hv
ICIke01FfTogRXhpdGluZyIgMT4mMiAKICBleGl0IDEKZmkKCmlmIGVjaG8gJERBWVMgfCBncmVw
IC1xICdbXjAtOV0nIHx8IFsgJERBWVMgLWx0IDEgXSA7IHRoZW4KICBVU0FHRQogIGV4aXQgMQpm
aQoKCmlmICEgWyAtZiAiJHtJTkZJTEV9IiBdIDsgdGhlbgogIFVTQUdFCiAgZXhpdCAxCmZpCgpD
Tj0iJChvcGVuc3NsIHJlcSAtaW4gIiR7SU5GSUxFfSIgLW5vb3V0IC1zdWJqZWN0IHwgZ3JlcCAt
RSAtbyAnQ04gKj0gKlswLTlhLXpBLVpdWzAtOWEtekEtWi4tXSpbWzAtOWEtekEtWl0nIHwgdHIg
J0EtWicgJ2EteicgfCBjdXQgLWQ9IC1mMiB8IHRyIC1kYyAnWzAtOWEtei4tXScpIgoKaWYgISBl
Y2hvICIke0NOfSIgfCBncmVwIC1FcWkgJ15bMC05YS16XVswLTlhLXouLV0qWzAtOWEtel0kJzsg
dGhlbgogIGVjaG8gIiR7TUV9OiBJbnZhbGlkIENOIChtdXN0IGJlIHZhbGlkIEZRRE4pIiAxPiYy
CiAgZXhpdCAxCmZpCgppZiAhIG9wZW5zc2wgZGdzdCAiLSR7RElHRVNUfSIgPiAvZGV2L251bGwg
Mj4mMSA8IC9kZXYvbnVsbDsgdGhlbgogIGVjaG8gIiR7TUV9OiBJbnZhbGlkIGRpZ2VzdC4gQ2Fu
J3QgcHJvY2VlZCIgMT4mMgogIGV4aXQgMQpmaQogCgpSRVFESVI9IiR7Q0FESVJ9L3JlcXMvJHtD
Tn0vJHtEfSIKQ1JURElSPSIke0NBRElSfS9jZXJ0cy8ke0NOfS8ke0R9IgpFWFRGSUxFPSIke1JF
UURJUn0vJHtDTn0uZXh0IgpSRVFGSUxFPSIke1JFUURJUn0vJHtDTn0uY3NyIgpDUlRGSUxFPSIk
e0NSVERJUn0vJHtDTn0uY3J0IgpDQVNFUklBTD0iJHtDUlRESVJ9LyR7Q059LnNybCIKCm1rZGly
IC1wICIke0NSVERJUn0iICIke1JFUURJUn0iCnNldCAtQwoKdGVzdCAtZSAiJHtSRVFGSUxFfSIg
fHwgY3AgLWkgIiR7SU5GSUxFfSIgIiR7UkVRRklMRX0iCgpjYXQgPiAiJHtFWFRGSUxFfSIgPDxf
CmF1dGhvcml0eUtleUlkZW50aWZpZXI9a2V5aWQsaXNzdWVyCmJhc2ljQ29uc3RyYWludHM9Q0E6
RkFMU0UKa2V5VXNhZ2UgPSBkaWdpdGFsU2lnbmF0dXJlLCBrZXlFbmNpcGhlcm1lbnQKc3ViamVj
dEFsdE5hbWUgPSBAYWx0X25hbWVzCgpbYWx0X25hbWVzXQpfCgpzZXQgK0MKewpkPTE7ZT0xO2k9
MQpBTFROQU1FUz0kKG9wZW5zc2wgcmVxIC1pbiAiJHtSRVFGSUxFfSIgLXRleHQgXAogIHwgZmdy
ZXAgIC1BIDIwMCAnIFg1MDl2MyBTdWJqZWN0IEFsdGVybmF0aXZlIE5hbWU6JyBcCiAgfCBncmVw
IC1FICdeW1s6c3BhY2U6XV0qKEROU3xlbWFpbHxJUCBBZGRyZXNzKTpbXixdKycgXAogIHwgdHIg
LWQgIiBcdCIgfCB0ciAiLCIgIlxuIiB8IHNvcnQpCndoaWxlIHJlYWQgbDsgZG8KICBjYXNlICIk
bCIgaW4gCiAgICBETlM6KikgaXRlbT0iRE5TIjsgZWNobyAkbCB8IHNlZCAicy9eJHtpdGVtfTpc
KC4qXCkkLyR7aXRlbX0uJHtkfSA9IFwxLyI7IGQ9JCgoZCsxKSkgOzsKICAgIGVtYWlsOiopIGl0
ZW09ImVtYWlsIjsgZWNobyAkbCB8IHNlZCAicy9eJHtpdGVtfTpcKC4qXCkkLyR7aXRlbX0uJHtl
fSA9IFwxLyI7IGU9JCgoZSsxKSkgOzsKICAgIElQQWRkcmVzczoqKSBpdGVtPSJJUEFkZHJlc3Mi
OyBlY2hvICRsIHwgc2VkICJzL14ke2l0ZW19OlwoLipcKSQvSVAuJHtpfSA9IFwxLyI7IGk9JCgo
MSsxKSkgOzsKICBlc2FjCmRvbmUgPDxfCiRBTFROQU1FUwpfCmVjaG8gZW1haWwuJHtlfSA9IGNv
cHkKfSA+PiAiJHtFWFRGSUxFfSIKCnNldCAtQwpvcGVuc3NsIHg1MDkgLXJlcSAtaW4gIiR7UkVR
RklMRX0iIC1DQSAiJHtDQUNSVH0iIC1DQWtleSAiJHtDQUtFWX0iIC1DQWNyZWF0ZXNlcmlhbCAt
Q0FzZXJpYWwgIiR7Q0FTRVJJQUx9IiAiLSR7RElHRVNUfSIgLWV4dGZpbGUgIiR7RVhURklMRX0i
ID4gIiR7Q1JURklMRX0iIC1kYXlzICIke0RBWVN9IgoKZWNobyAiJHtNRX06IFdyb3RlIGNlcnRp
ZmljYXRlIHRvICR7Q1JURklMRX0iCg==
"

CANAME=""
CASUBJECT=""
PRINT_SCRIPT_SH=0

while getopts b:d:l:n:ps:t: opt;do
  case $opt in 
    b) BASEDIR=${OPTARG};;
    d) DIGEST=${OPTARG};;
    l) RSA_KEY_LENGTH=${OPTARG};;
    n) CANAME=${OPTARG};;
    p) PRINT_SCRIPT_SH=1;;
    s) CASUBJECT=${OPTARG};;
    t) DAYS=${OPTARG};;
    *) USAGE;exit 1 ;;
  esac
done

if [ ${PRINT_SCRIPT_SH} -gt 0 ]; then
  base64 -d <<-_
	$SIGN_SH_SRC
	_
	exit 0
fi


if echo $DAYS | grep -q '[^0-9]' || [ $DAYS -lt 1 ] ; then
  USAGE
  exit 1
fi

if echo "${RSA_KEY_LENGTH}" | grep -q '[^0-9]' || [ "${RSA_KEY_LENGTH}" -lt 2048 ] ; then
  USAGE
  exit 1
fi

if ! [ -d "${BASEDIR}" ] ; then
  USAGE
  exit 1
fi

if [ -z "${CASUBJECT}" ] ; then
  USAGE
  exit 1
fi

if ! echo "${CANAME}" | grep -Eq "${CANAME_RE}" ; then
  USAGE
  exit 1
fi

if ! openssl dgst "-${DIGEST}" > /dev/null 2>&1 < /dev/null; then
  echo "${ME}: Invalid digest. Can't proceed" 1>&2
  exit 1
fi

CADIR="${BASEDIR}/${CANAME}"
SIGN_SH="${CADIR}/sign.sh"
CACRT="${CADIR}/CA/${CANAME}.crt"
CAKEY="${CADIR}/CA/${CANAME}.key"
if [ -d "${BASEDIR}/${CANAME}" ] ; then
  echo "${ME}: Directory for CA '${BASEDIR}/${CANAME}' already exists. Exiting" 1>&2
  exit 1
fi

mkdir "${CADIR}"
mkdir -p "${CADIR}/CA" "${CADIR}/reqs" "${CADIR}/certs" "${CADIR}/incoming"

set -C 
base64 -d > "${SIGN_SH}" <<_
$SIGN_SH_SRC
_
chmod 700 "${SIGN_SH}"
openssl genpkey -algorithm RSA "-${KEYCRYPTALGO}" -pkeyopt "rsa_keygen_bits:${RSA_KEY_LENGTH}" > "${CAKEY}"
openssl req -x509 -new -key "${CAKEY}" "-${DIGEST}" -days "${DAYS}" -subj "$CASUBJECT" > "${CACRT}"
set +C
