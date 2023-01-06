#!/bin/bash
#
# Author: github.com/xae7Jeze
#
V=20230106.9

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
OAoKc2V0IC1lIC11CgpQQVRIPSIvYmluOi91c3IvYmluOi9zYmluOi91c3Ivc2JpbiIKTENfQUxM
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
ZXJ0cy88Y29tbW9uX25hbWU+LzxZWVlZbW1kZEhITU1TUz4KCQoJICBWZXJzaW9uOiAkVgoJCglf
Cn0KCndoaWxlIGdldG9wdHMgZDppOnQ6IG9wdDtkbwogIGNhc2UgJG9wdCBpbiAKICAgIGQpIERJ
R0VTVD0ke09QVEFSR307OwogICAgaSkgSU5GSUxFPSR7T1BUQVJHfTs7CiAgICB0KSBEQVlTPSR7
T1BUQVJHfTs7CiAgICAqKSBVU0FHRTtleGl0IDEgOzsKICBlc2FjCmRvbmUKCmlmICEgWyAtZiAi
JHtDQUNSVH0iIC1hIC1mICIke0NBS0VZfSIgXTsgdGhlbgogIGVjaG8gIiR7TUV9OiBNaXNzaW5n
ICcke0NBQ1JUfScgYW5kL29yICcke0NBS0VZfScgaW4gJyR7Q0FESVJ9L0NBLyciIDE+JjIgCiAg
ZWNobyAiJHtNRX06IEFtIEkgaW4gdGhlIHRvcCBsZXZlbCBvZiBhIENBLURpcmVjdG9yeS1TdHJ1
Y3R1cmU/IiAxPiYyIAogIGVjaG8gIiR7TUV9OiBFeGl0aW5nIiAxPiYyIAogIGV4aXQgMQpmaQoK
aWYgZWNobyAkREFZUyB8IGdyZXAgLXEgJ1teMC05XScgfHwgWyAkREFZUyAtbHQgMSBdIDsgdGhl
bgogIFVTQUdFCiAgZXhpdCAxCmZpCgoKaWYgISBbIC1mICIke0lORklMRX0iIF0gOyB0aGVuCgll
Y2hvICIke01FfTogRVJST1I6IE9wZW5pbmcgaW5wdXQgZmlsZSBmYWlsZWQiIDE+JjIKICBleGl0
IDEKZmkKCkNOPSIkKG9wZW5zc2wgcmVxIC1pbiAiJHtJTkZJTEV9IiAtbm9vdXQgLXN1YmplY3Qg
fCBncmVwIC1FIC1vICdDTiAqPSAqWzAtOWEtekEtWl1bMC05YS16QS1aLi1dKltbMC05YS16QS1a
XScgfCB0ciAnQS1aJyAnYS16JyB8IGN1dCAtZD0gLWYyIHwgdHIgLWRjICdbMC05YS16Li1dJyki
CgppZiAhIGVjaG8gIiR7Q059IiB8IGdyZXAgLUVxaSAnXlswLTlhLXpdWzAtOWEtei4tXSpbMC05
YS16XSQnOyB0aGVuCiAgZWNobyAiJHtNRX06IEludmFsaWQgQ04gKG11c3QgYmUgdmFsaWQgRlFE
TikiIDE+JjIKICBleGl0IDEKZmkKCmlmICEgb3BlbnNzbCBkZ3N0ICItJHtESUdFU1R9IiA+IC9k
ZXYvbnVsbCAyPiYxIDwgL2Rldi9udWxsOyB0aGVuCiAgZWNobyAiJHtNRX06IEludmFsaWQgZGln
ZXN0LiBDYW4ndCBwcm9jZWVkIiAxPiYyCiAgZXhpdCAxCmZpCiAKClJFUURJUj0iJHtDQURJUn0v
cmVxcy8ke0NOfS8ke0R9IgpDUlRESVI9IiR7Q0FESVJ9L2NlcnRzLyR7Q059LyR7RH0iCkVYVEZJ
TEU9IiR7UkVRRElSfS8ke0NOfS5leHQiClJFUUZJTEU9IiR7UkVRRElSfS8ke0NOfS5jc3IiCkNS
VEZJTEU9IiR7Q1JURElSfS8ke0NOfS5jcnQiCkNBU0VSSUFMPSIke0NSVERJUn0vJHtDTn0uc3Js
IgoKbWtkaXIgLXAgIiR7Q1JURElSfSIgIiR7UkVRRElSfSIKc2V0IC1DCgp0ZXN0IC1lICIke1JF
UUZJTEV9IiB8fCBjcCAtaSAiJHtJTkZJTEV9IiAiJHtSRVFGSUxFfSIKCmNhdCA+ICIke0VYVEZJ
TEV9IiA8PF8KYXV0aG9yaXR5S2V5SWRlbnRpZmllcj1rZXlpZCxpc3N1ZXIKYmFzaWNDb25zdHJh
aW50cz1DQTpGQUxTRQprZXlVc2FnZSA9IGRpZ2l0YWxTaWduYXR1cmUsIGtleUVuY2lwaGVybWVu
dApzdWJqZWN0QWx0TmFtZSA9IEBhbHRfbmFtZXMKClthbHRfbmFtZXNdCl8KCnNldCArQwp7CmQ9
MTtlPTE7aT0xCkFMVE5BTUVTPSQob3BlbnNzbCByZXEgLWluICIke1JFUUZJTEV9IiAtdGV4dCBc
CiAgfCBmZ3JlcCAgLUEgMjAwICcgWDUwOXYzIFN1YmplY3QgQWx0ZXJuYXRpdmUgTmFtZTonIFwK
ICB8IGdyZXAgLUUgJ15bWzpzcGFjZTpdXSooRE5TfGVtYWlsfElQIEFkZHJlc3MpOlteLF0rJyBc
CiAgfCB0ciAtZCAiIFx0IiB8IHRyICIsIiAiXG4iIHwgc29ydCkKd2hpbGUgcmVhZCBsOyBkbwog
IGNhc2UgIiRsIiBpbiAKICAgIEROUzoqKSBpdGVtPSJETlMiOyBlY2hvICRsIHwgc2VkICJzL14k
e2l0ZW19OlwoLipcKSQvJHtpdGVtfS4ke2R9ID0gXDEvIjsgZD0kKChkKzEpKSA7OwogICAgZW1h
aWw6KikgaXRlbT0iZW1haWwiOyBlY2hvICRsIHwgc2VkICJzL14ke2l0ZW19OlwoLipcKSQvJHtp
dGVtfS4ke2V9ID0gXDEvIjsgZT0kKChlKzEpKSA7OwogICAgSVBBZGRyZXNzOiopIGl0ZW09IklQ
QWRkcmVzcyI7IGVjaG8gJGwgfCBzZWQgInMvXiR7aXRlbX06XCguKlwpJC9JUC4ke2l9ID0gXDEv
IjsgaT0kKCgxKzEpKSA7OwogIGVzYWMKZG9uZSA8PF8KJEFMVE5BTUVTCl8KZWNobyBlbWFpbC4k
e2V9ID0gY29weQp9ID4+ICIke0VYVEZJTEV9IgoKc2V0IC1DCm9wZW5zc2wgeDUwOSAtcmVxIC1p
biAiJHtSRVFGSUxFfSIgLUNBICIke0NBQ1JUfSIgLUNBa2V5ICIke0NBS0VZfSIgLUNBY3JlYXRl
c2VyaWFsIC1DQXNlcmlhbCAiJHtDQVNFUklBTH0iICItJHtESUdFU1R9IiAtZXh0ZmlsZSAiJHtF
WFRGSUxFfSIgPiAiJHtDUlRGSUxFfSIgLWRheXMgIiR7REFZU30iCgplY2hvICIke01FfTogV3Jv
dGUgY2VydGlmaWNhdGUgdG8gJHtDUlRGSUxFfSIK
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
for i in 1 2 3; do 
  KEY=$(openssl genpkey -algorithm RSA "-${KEYCRYPTALGO}" -pkeyopt "rsa_keygen_bits:${RSA_KEY_LENGTH}" 2>/dev/null) && break
  echo "${ME}: Error passphrase to short or didn't match. Try again when prompted" 1>&2
done
if [ -z "${KEY}" ]; then
  echo "${ME}: Error generationg private key" 1>&2
	exit 1
fi
cat > "${CAKEY}" <<_
$KEY
_
unset KEY
for i in 1 2 3; do 
  CRT=$(openssl req -x509 -new -key "${CAKEY}" "-${DIGEST}" -days "${DAYS}" -subj "$CASUBJECT" 2>/dev/null) && break
  echo "${ME}: Error passphrase didn't match. Try again" 1>&2
done
if [ -z "${CRT}" ]; then
  echo "${ME}: Error generationg certificate" 1>&2
	exit 1
fi
cat > "${CACRT}" <<_
$CRT
_
unset CRT
set +C
echo "${ME}: CA created in ${CADIR}"
