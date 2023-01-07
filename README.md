# simpleCA
## Hint
__These scripts are not really tested and probably erroneous. You can use them at your own risk. No warranty given.__
## Synopsis
simpleCA is a collection of scripts to create a very simple CA and sign requests with it.
## Scripts in scripts/
* newCA.sh: Creates a new CA-Certificate and CA directory structure:
```
<BASE_DIRECTORY>/<CA_NAME>/  
   sign.sh (script to sign requests)  
   CA/  
     <CA_NAME>.crt (CA-Certificate)  
     <CA_NAME>.key (CA Private Key. Only RSA for now)  
   certs/ (for signed certs)  
   incoming/ (for incoming signing requests)  
   reqs/ (for request and extension files)  
```
* scripts.sh: Signs requests
* newreq.sh: Creates a new request

_All scripts give help when called with `-h`_
## Example
* First create a user for ca actions: `useradd -d /home/_EXAMPLE_USER_ -m -s /usr/sbin/nologin _EXAMPLE_USER_
* sudo or su to _EXAMPLE_USER_
* Checkout simpleCA to /home/_EXAMPLE_USER_/simpleCA :  `git clone https://github.com/xae7Jeze/simpleCA.git`
* Create directory for CAs: mkdir `/home/_EXAMPLE_USER_/CAs && chmod 700 /home/_EXAMPLE_USER_/CAs`
* Create new CA in /home/_EXAMPLE_USER_/CAs/testCA 
```
cd /home/_EXAMPLE_USER_/simpleCA/scripts
./newCA.sh -b /home/_EXAMPLE_USER_/CAs -n testCA -s '/CN=blabla/O=blub'
* Create a request with subject `CN=example.com` in `/home/_EXAMPLE_USER_/CAs/testCA/incoming/example.com/<YYYYmmddHHMMSS>`
./newreq.sh -s '/CN=example.com/' -o /home/_EXAMPLE_USER_/CAs/testCA/incoming/
```
* Sign request and write resulting certificate to /home/_EXAMPLE_USER_/CAs/testCA/certs/example.com/<YYYYmmddHHMMSS>
```
cd /home/_EXAMPLE_USER_/CAs/testCA/
./sign.sh -i /home/_EXAMPLE_USER_/CAs/testCA/incoming/example.com/<YYYYmmddHHMMSS>/example.com.csr
```
