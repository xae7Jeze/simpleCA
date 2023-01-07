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
* First create a user for ca actions: `useradd -d /home/EXAMPLE_USER -m -s /usr/sbin/nologin EXAMPLE_USER
* sudo or su to EXAMPLE_USER
* Checkout simpleCA to /home/EXAMPLE_USER/simpleCA :  `git clone https://github.com/xae7Jeze/simpleCA.git`
* Create directory for CAs: mkdir `/home/EXAMPLE_USER/CAs && chmod 700 /home/EXAMPLE_USER/CAs`
* Create new CA in /home/EXAMPLE_USER/CAs/testCA 
```
cd /home/EXAMPLE_USER/simpleCA/scripts
./newCA.sh -b /home/EXAMPLE_USER/CAs -n testCA -s '/CN=blabla/O=blub'
* Create a request with subject `CN=example.com` in `/home/EXAMPLE_USER/CAs/testCA/incoming/example.com/<YYYYmmddHHMMSS>`
./newreq.sh -s '/CN=example.com/' -o /home/EXAMPLE_USER/CAs/testCA/incoming/
```
* Sign request and write resulting certificate to /home/EXAMPLE_USER/CAs/testCA/certs/example.com/<YYYYmmddHHMMSS>
```
cd /home/EXAMPLE_USER/CAs/testCA/
./sign.sh -i /home/EXAMPLE_USER/CAs/testCA/incoming/example.com/<YYYYmmddHHMMSS>/example.com.csr
```
