#!/bin/bash
#
V=20230106.1

set -e -u

PATH="/bin:/usr/bin:/sbin:/usr/sbin"
LC_ALL=C
LANG=C
umask 077
ME=${0##*/}

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
IyEvYmluL2Jhc2gKIwpWPTIwMjMwMTA2LjEKCnNldCAtZSAtdQoKUEFUSD0iL2JpbjovdXNyL2Jp
bjovc2JpbjovdXNyL3NiaW4iCkxDX0FMTD1DCkxBTkc9QwpNRT0kezAjIyovfQp1bWFzayAwNzcK
CgppZiBlY2hvICIkezB9IiB8IGZncmVwIC1xIC8gOyB0aGVuCiAgTVlESVI9JHswJS8qfQplbHNl
CiAgTVlESVI9IiQod2hpY2ggIiR7MH0iIHx8IGVjaG8gLikiCiAgTVlESVI9JHtNWURJUiUvKn0K
ZmkKTVlESVI9IiQoY2QgIiR7TVlESVJ9IiAmJiBwd2QgLVApIgpDQU5BTUU9JHtNWURJUiMjKi99
CgpEPSQoZGF0ZSAiKyVZJW0lZCIpCkNBRElSPSR7TVlESVJ9CkNBQ1JUPSIke0NBRElSfS9DQS8k
e0NBTkFNRX0uY3J0IgpDQUtFWT0iJHtDQURJUn0vQ0EvJHtDQU5BTUV9LmtleSIKQ0FTRVJJQUw9
IiR7Q0FESVJ9L0NBL3NlcmlhbC50eHQiCkRJR0VTVD0ic2hhMjU2IgpEQVlTPTM2NQpJTkZJTEU9
IiIKClVTQUdFKCkgewogIGNhdCA8PC1fCglVc2FnZTogJHtNRX0gWyAtZCA8bWVzc2FnZV9kaWdl
c3Q+IC10IDxkYXlzPl0gLWkgPHJlcXVlc3RmaWxlPgoJRGVmYXVsdHM6CgktZCAtPiAke0RJR0VT
VH0KCS1pIC0+IE5PREVGQVVMVAoJLXQgLT4gJHtEQVlTfSAoVGltZSBpbiBkYXlzIGNlcnRpZmlj
YXRlIGlzIHZhbGlkKQoJCglWZXJzaW9uOiAkViAgICAgCgkKCV8KfQoKd2hpbGUgZ2V0b3B0cyBk
Omk6dDogb3B0O2RvCiAgY2FzZSAkb3B0IGluIAogICAgZCkgRElHRVNUPSR7T1BUQVJHfTs7CiAg
ICBpKSBJTkZJTEU9JHtPUFRBUkd9OzsKICAgIHQpIERBWVM9JHtPUFRBUkd9OzsKICAgICopIFVT
QUdFO2V4aXQgMSA7OwogIGVzYWMKZG9uZQoKaWYgISBbIC1mICIke0NBQ1JUfSIgLWEgLWYgIiR7
Q0FLRVl9IiBdOyB0aGVuCiAgZWNobyAiJHtNRX06IE1pc3NpbmcgJyR7Q0FDUlR9JyBhbmQvb3Ig
JyR7Q0FLRVl9JyBpbiAnJHtDQURJUn0vQ0EvJyIgMT4mMiAKICBlY2hvICIke01FfTogQW0gSSBp
biB0aGUgdG9wIGxldmVsIG9mIENBLURpcmVjdG9yeS1TdHJ1Y3R1cmU/IiAxPiYyIAogIGVjaG8g
IiR7TUV9OiBFeGl0aW5nIiAxPiYyIAogIGV4aXQgMQpmaQoKaWYgZWNobyAkREFZUyB8IGdyZXAg
LXEgJ1teMC05XScgfHwgWyAkREFZUyAtbHQgMSBdIDsgdGhlbgogIFVTQUdFCiAgZXhpdCAxCmZp
CgoKaWYgISBbIC1mICIke0lORklMRX0iIF0gOyB0aGVuCiAgVVNBR0UKICBleGl0IDEKZmkKCkNO
PSIkKG9wZW5zc2wgcmVxIC1pbiAiJHtJTkZJTEV9IiAtbm9vdXQgLXN1YmplY3QgfCBncmVwIC1F
IC1vICdDTiAqPSAqWzAtOWEtekEtWl1bMC05YS16QS1aLi1dKltbMC05YS16QS1aXScgfCB0ciAn
QS1aJyAnYS16JyB8IGN1dCAtZD0gLWYyIHwgdHIgLWRjICdbMC05YS16Li1dJykiCgppZiAhIGVj
aG8gIiR7Q059IiB8IGVncmVwIC1xaSAnXlswLTlhLXpdWzAtOWEtei4tXSpbMC05YS16XSQnOyB0
aGVuCiAgZWNobyAiJHtNRX06IEludmFsaWQgQ04gKG11c3QgYmUgdmFsaWQgRlFETikiIDE+JjIK
ICBleGl0IDEKZmkKCmlmICEgb3BlbnNzbCBkZ3N0ICItJHtESUdFU1R9IiA+IC9kZXYvbnVsbCAy
PiYxIDwgL2Rldi9udWxsOyB0aGVuCiAgZWNobyAiJHtNRX06IEludmFsaWQgZGlnZXN0LiBDYW4n
dCBwcm9jZWVkIiAxPiYyCiAgZXhpdCAxCmZpCiAKClJFUURJUj0iJHtDQURJUn0vcmVxcy8ke0R9
LyR7Q059IgpDUlRESVI9IiR7Q0FESVJ9L2NlcnRzLyR7RH0vJHtDTn0iCkVYVEZJTEU9IiR7UkVR
RElSfS8ke0NOfS5leHQiClJFUUZJTEU9IiR7UkVRRElSfS8ke0NOfS5jc3IiCkNSVEZJTEU9IiR7
Q1JURElSfS8ke0NOfS5jcnQiCgpta2RpciAtcCAiJHtDUlRESVJ9IiAiJHtSRVFESVJ9IgpzZXQg
LUMKCnRlc3QgLWUgIiR7UkVRRklMRX0iIHx8IGNwIC1pICIke0lORklMRX0iICIke1JFUUZJTEV9
IgoKaWYgISB0ZXN0ICIkKHNoYTI1NnN1bSA8ICIke0lORklMRX0iKSIgPSAiJChzaGEyNTZzdW0g
PCAiJHtSRVFGSUxFfSIpIjsgdGhlbgogIGVjaG8gIiR7TUV9OiBDb3B5IGlucHV0IGZpbGUgdG8g
cmVxdWVzdCBkaXIgZmFpbGVkIiAxPiYyCiAgZXhpdCAxCmZpCgpjYXQgPiAiJHtFWFRGSUxFfSIg
PDxfCmF1dGhvcml0eUtleUlkZW50aWZpZXI9a2V5aWQsaXNzdWVyCmJhc2ljQ29uc3RyYWludHM9
Q0E6RkFMU0UKa2V5VXNhZ2UgPSBkaWdpdGFsU2lnbmF0dXJlLCBub25SZXB1ZGlhdGlvbiwga2V5
RW5jaXBoZXJtZW50LCBkYXRhRW5jaXBoZXJtZW50CnN1YmplY3RBbHROYW1lID0gQGFsdF9uYW1l
cwoKW2FsdF9uYW1lc10KXwoKc2V0ICtDCnsKZD0xO2U9MTtpPTEKQUxUTkFNRVM9JChvcGVuc3Ns
IHJlcSAtaW4gIiR7UkVRRklMRX0iIC10ZXh0IFwKICB8IGZncmVwICAtQSAyMDAgJyBYNTA5djMg
U3ViamVjdCBBbHRlcm5hdGl2ZSBOYW1lOicgXAogIHwgZ3JlcCAtRSAnXltbOnNwYWNlOl1dKihE
TlN8ZW1haWx8SVAgQWRkcmVzcyk6W14sXSsnIFwKICB8IHRyIC1kICIgXHQiIHwgdHIgIiwiICJc
biIgfCBzb3J0KQp3aGlsZSByZWFkIGw7IGRvCiAgY2FzZSAiJGwiIGluIAogICAgRE5TOiopIGl0
ZW09IkROUyI7IGVjaG8gJGwgfCBzZWQgInMvXiR7aXRlbX06XCguKlwpJC8ke2l0ZW19LiR7ZH0g
PSBcMS8iOyBkPSQoKGQrMSkpIDs7CiAgICBlbWFpbDoqKSBpdGVtPSJlbWFpbCI7IGVjaG8gJGwg
fCBzZWQgInMvXiR7aXRlbX06XCguKlwpJC8ke2l0ZW19LiR7ZX0gPSBcMS8iOyBlPSQoKGUrMSkp
IDs7CiAgICBJUEFkZHJlc3M6KikgaXRlbT0iSVBBZGRyZXNzIjsgZWNobyAkbCB8IHNlZCAicy9e
JHtpdGVtfTpcKC4qXCkkL0lQLiR7aX0gPSBcMS8iOyBpPSQoKDErMSkpIDs7CiAgZXNhYwpkb25l
IDw8XwokQUxUTkFNRVMKXwplY2hvIGVtYWlsLiR7ZX0gPSBjb3B5Cn0gPj4gIiR7RVhURklMRX0i
CgpzZXQgLUMKb3BlbnNzbCB4NTA5IC1yZXEgLWluICIke1JFUUZJTEV9IiAtQ0EgIiR7Q0FDUlR9
IiAtQ0FrZXkgIiR7Q0FLRVl9IiAtQ0FjcmVhdGVzZXJpYWwgLUNBc2VyaWFsICIke0NBU0VSSUFM
fSIgIi0ke0RJR0VTVH0iIC1leHRmaWxlICIke0VYVEZJTEV9IiA+ICIke0NSVEZJTEV9IiAtZGF5
cyAiJHtEQVlTfSIK
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
  echo "${ME}: Directory for CA '${BASEDIR}/${CANAME}' already existsi. Exiting" 1>&2
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
