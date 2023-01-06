#!/bin/bash
#
# Author: github.com/xae7Jeze
#
V=20230106.4

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
      serial.txt (Serial Number File)
    certs/
    incoming/
    reqs/
	
	Version: $V
	
	_
}


SIGN_SH_SRC="
IyEvYmluL2Jhc2gKIwojIEF1dGhvcjogZ2l0aHViLmNvbS94YWU3SmV6ZQojClY9MjAyMzAxMDYu
MwoKc2V0IC1lIC11CgpQQVRIPSIvYmluOi91c3IvYmluOi9zYmluOi91c3Ivc2JpbiIKTENfQUxM
PUMKTEFORz1DCk1FPSR7MCMjKi99CnVtYXNrIDA3NwoKTVlVSUQ9JChpZCAtdSkKaWYgWyAke01Z
VUlEOi0wfSAtZXEgMCBdOyB0aGVuCiAgZWNobyAiJHtNRX06IFdvbid0IHJ1biB3aXRoIFVJRCAw
IChyb290KS4gRXhpdGluZyIgMT4mMgogIGV4aXQgMQpmaQoKaWYgZWNobyAiJHswfSIgfCBmZ3Jl
cCAtcSAvIDsgdGhlbgogIE1ZRElSPSR7MCUvKn0KZWxzZQogIE1ZRElSPSIkKHdoaWNoICIkezB9
IiB8fCBlY2hvIC4pIgogIE1ZRElSPSR7TVlESVIlLyp9CmZpCk1ZRElSPSIkKGNkICIke01ZRElS
fSIgJiYgcHdkIC1QKSIKQ0FOQU1FPSR7TVlESVIjIyovfQoKRD0kKGRhdGUgIislWSVtJWQiKQpD
QURJUj0ke01ZRElSfQpDQUNSVD0iJHtDQURJUn0vQ0EvJHtDQU5BTUV9LmNydCIKQ0FLRVk9IiR7
Q0FESVJ9L0NBLyR7Q0FOQU1FfS5rZXkiCkNBU0VSSUFMPSIke0NBRElSfS9DQS9zZXJpYWwudHh0
IgpESUdFU1Q9InNoYTI1NiIKREFZUz0zNjUKSU5GSUxFPSIiCgpVU0FHRSgpIHsKICBjYXQgPDwt
XwoJVXNhZ2U6ICR7TUV9IFsgLWQgPG1lc3NhZ2VfZGlnZXN0PiAtdCA8ZGF5cz5dIC1pIDxyZXF1
ZXN0ZmlsZT4KCURlZmF1bHRzOgoJLWQgLT4gJHtESUdFU1R9CgktaSAtPiBOT0RFRkFVTFQKCS10
IC0+ICR7REFZU30gKFRpbWUgaW4gZGF5cyBjZXJ0aWZpY2F0ZSBpcyB2YWxpZCkKCQoJVmVyc2lv
bjogJFYgICAgIAoJCglfCn0KCndoaWxlIGdldG9wdHMgZDppOnQ6IG9wdDtkbwogIGNhc2UgJG9w
dCBpbiAKICAgIGQpIERJR0VTVD0ke09QVEFSR307OwogICAgaSkgSU5GSUxFPSR7T1BUQVJHfTs7
CiAgICB0KSBEQVlTPSR7T1BUQVJHfTs7CiAgICAqKSBVU0FHRTtleGl0IDEgOzsKICBlc2FjCmRv
bmUKCmlmICEgWyAtZiAiJHtDQUNSVH0iIC1hIC1mICIke0NBS0VZfSIgXTsgdGhlbgogIGVjaG8g
IiR7TUV9OiBNaXNzaW5nICcke0NBQ1JUfScgYW5kL29yICcke0NBS0VZfScgaW4gJyR7Q0FESVJ9
L0NBLyciIDE+JjIgCiAgZWNobyAiJHtNRX06IEFtIEkgaW4gdGhlIHRvcCBsZXZlbCBvZiBhIENB
LURpcmVjdG9yeS1TdHJ1Y3R1cmU/IiAxPiYyIAogIGVjaG8gIiR7TUV9OiBFeGl0aW5nIiAxPiYy
IAogIGV4aXQgMQpmaQoKaWYgZWNobyAkREFZUyB8IGdyZXAgLXEgJ1teMC05XScgfHwgWyAkREFZ
UyAtbHQgMSBdIDsgdGhlbgogIFVTQUdFCiAgZXhpdCAxCmZpCgoKaWYgISBbIC1mICIke0lORklM
RX0iIF0gOyB0aGVuCiAgVVNBR0UKICBleGl0IDEKZmkKCkNOPSIkKG9wZW5zc2wgcmVxIC1pbiAi
JHtJTkZJTEV9IiAtbm9vdXQgLXN1YmplY3QgfCBncmVwIC1FIC1vICdDTiAqPSAqWzAtOWEtekEt
Wl1bMC05YS16QS1aLi1dKltbMC05YS16QS1aXScgfCB0ciAnQS1aJyAnYS16JyB8IGN1dCAtZD0g
LWYyIHwgdHIgLWRjICdbMC05YS16Li1dJykiCgppZiAhIGVjaG8gIiR7Q059IiB8IGdyZXAgLUVx
aSAnXlswLTlhLXpdWzAtOWEtei4tXSpbMC05YS16XSQnOyB0aGVuCiAgZWNobyAiJHtNRX06IElu
dmFsaWQgQ04gKG11c3QgYmUgdmFsaWQgRlFETikiIDE+JjIKICBleGl0IDEKZmkKCmlmICEgb3Bl
bnNzbCBkZ3N0ICItJHtESUdFU1R9IiA+IC9kZXYvbnVsbCAyPiYxIDwgL2Rldi9udWxsOyB0aGVu
CiAgZWNobyAiJHtNRX06IEludmFsaWQgZGlnZXN0LiBDYW4ndCBwcm9jZWVkIiAxPiYyCiAgZXhp
dCAxCmZpCiAKClJFUURJUj0iJHtDQURJUn0vcmVxcy8ke0R9LyR7Q059IgpDUlRESVI9IiR7Q0FE
SVJ9L2NlcnRzLyR7RH0vJHtDTn0iCkVYVEZJTEU9IiR7UkVRRElSfS8ke0NOfS5leHQiClJFUUZJ
TEU9IiR7UkVRRElSfS8ke0NOfS5jc3IiCkNSVEZJTEU9IiR7Q1JURElSfS8ke0NOfS5jcnQiCgpt
a2RpciAtcCAiJHtDUlRESVJ9IiAiJHtSRVFESVJ9IgpzZXQgLUMKCnRlc3QgLWUgIiR7UkVRRklM
RX0iIHx8IGNwIC1pICIke0lORklMRX0iICIke1JFUUZJTEV9IgoKY2F0ID4gIiR7RVhURklMRX0i
IDw8XwphdXRob3JpdHlLZXlJZGVudGlmaWVyPWtleWlkLGlzc3VlcgpiYXNpY0NvbnN0cmFpbnRz
PUNBOkZBTFNFCmtleVVzYWdlID0gZGlnaXRhbFNpZ25hdHVyZSwga2V5RW5jaXBoZXJtZW50CnN1
YmplY3RBbHROYW1lID0gQGFsdF9uYW1lcwoKW2FsdF9uYW1lc10KXwoKc2V0ICtDCnsKZD0xO2U9
MTtpPTEKQUxUTkFNRVM9JChvcGVuc3NsIHJlcSAtaW4gIiR7UkVRRklMRX0iIC10ZXh0IFwKICB8
IGZncmVwICAtQSAyMDAgJyBYNTA5djMgU3ViamVjdCBBbHRlcm5hdGl2ZSBOYW1lOicgXAogIHwg
Z3JlcCAtRSAnXltbOnNwYWNlOl1dKihETlN8ZW1haWx8SVAgQWRkcmVzcyk6W14sXSsnIFwKICB8
IHRyIC1kICIgXHQiIHwgdHIgIiwiICJcbiIgfCBzb3J0KQp3aGlsZSByZWFkIGw7IGRvCiAgY2Fz
ZSAiJGwiIGluIAogICAgRE5TOiopIGl0ZW09IkROUyI7IGVjaG8gJGwgfCBzZWQgInMvXiR7aXRl
bX06XCguKlwpJC8ke2l0ZW19LiR7ZH0gPSBcMS8iOyBkPSQoKGQrMSkpIDs7CiAgICBlbWFpbDoq
KSBpdGVtPSJlbWFpbCI7IGVjaG8gJGwgfCBzZWQgInMvXiR7aXRlbX06XCguKlwpJC8ke2l0ZW19
LiR7ZX0gPSBcMS8iOyBlPSQoKGUrMSkpIDs7CiAgICBJUEFkZHJlc3M6KikgaXRlbT0iSVBBZGRy
ZXNzIjsgZWNobyAkbCB8IHNlZCAicy9eJHtpdGVtfTpcKC4qXCkkL0lQLiR7aX0gPSBcMS8iOyBp
PSQoKDErMSkpIDs7CiAgZXNhYwpkb25lIDw8XwokQUxUTkFNRVMKXwplY2hvIGVtYWlsLiR7ZX0g
PSBjb3B5Cn0gPj4gIiR7RVhURklMRX0iCgpzZXQgLUMKb3BlbnNzbCB4NTA5IC1yZXEgLWluICIk
e1JFUUZJTEV9IiAtQ0EgIiR7Q0FDUlR9IiAtQ0FrZXkgIiR7Q0FLRVl9IiAtQ0FjcmVhdGVzZXJp
YWwgLUNBc2VyaWFsICIke0NBU0VSSUFMfSIgIi0ke0RJR0VTVH0iIC1leHRmaWxlICIke0VYVEZJ
TEV9IiA+ICIke0NSVEZJTEV9IiAtZGF5cyAiJHtEQVlTfSIK
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
CASERIAL="${CADIR}/CA/serial.txt"
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
> "${CASERIAL}"
base64 -d > "${SIGN_SH}" <<_
$SIGN_SH_SRC
_
chmod 700 "${SIGN_SH}"
openssl genpkey -algorithm RSA "-${KEYCRYPTALGO}" -pkeyopt "rsa_keygen_bits:${RSA_KEY_LENGTH}" > "${CAKEY}"
openssl req -x509 -new -key "${CAKEY}" "-${DIGEST}" -days "${DAYS}" -subj "$CASUBJECT" > "${CACRT}"
set +C
