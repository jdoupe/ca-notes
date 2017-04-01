OpenSSL
https://jamielinux.com/docs/openssl-certificate-authority/

Vault
http://cuddletech.com/?p=959
http://marsdominion.com/2016/10/26/using-vault-as-a-certificate-authority/
https://blog.kintoandar.com/2015/11/vault-PKI-made-easy.html
https://www.vaultproject.io/docs/index.html

Create root pair
----------------
mkdir -p root/ca/certs root/ca/crl root/ca/newcerts root/ca/private
chmod 700 root/ca/private
touch root/ca/index.txt
echo 1000 > root/ca/serial

# Debating whether to document contents of openssl.cnf (root & intermediate), 
# and leave it at that, or put the necessary configuration on the command 
# lines, and let the reader move to a file if desired.

cp openssl-root.cnf root/ca/openssl.cnf

Create root key
---------------

openssl genrsa -aes256 -out root/ca/private/ca.key.pem 4096
chmod 400 root/ca/private/ca.key.pem

Create root certificate
-----------------------

openssl req -config root/ca/openssl.cnf \
  -key root/ca/private/ca.key.pem \
  -new -x509 -days 7300 -sha256 -extensions v3_ca \
  -out root/ca/certs/ca.cert.pem

chmod 444 root/ca/certs/ca.cert.pem

Verify root certificate
-----------------------

openssl x509 -noout -text -in root/ca/certs/ca.cert.pem

Create intermediate pair
------------------------

mkdir -p root/ca/intermediate/certs root/ca/intermediate/crl root/ca/intermediate/csr root/ca/intermediate/newcerts root/ca/intermediate/private
chmod 700 root/ca/intermediate/private
touch root/ca/intermediate/index.txt
echo 1000 > root/ca/intermediate/serial

echo 1000 > root/ca/intermediate/crlnumber

cp openssl-intermediate.cnf root/ca/intermediate/openssl.cnf

Create intermediate key
-----------------------

openssl genrsa -aes256 -out root/ca/intermediate/private/intermediate.key.pem 4096

chmod 400 root/ca/intermediate/private/intermediate.key.pem

Create intermediate certificate
-------------------------------

openssl req -config root/ca/intermediate/openssl.cnf -new -sha256 \
  -key root/ca/intermediate/private/intermediate.key.pem \
  -out root/ca/intermediate/csr/intermediate.csr.pem

openssl ca -config root/ca/openssl.cnf -extensions v3_intermediate_ca \
  -days 3650 -notext -md sha256 \
  -in root/ca/intermediate/csr/intermediate.csr.pem \
  -out root/ca/intermediate/certs/intermediate.cert.pem

chmod 444 root/ca/intermediate/certs/intermediate.cert.pem


Edit Configuration
------------------

    #SSL certificates need a "Subject Alternative Name" field defined.  
    #OpenSSL apparently does NOT allow you to specify this on the command 
    #line, so we need to edit the configuration file to provide the correct 
    #information.

    #THIS IS NO LONGER NECESSARY - please see options below in the signing 
    #section

#    cd test-ca
#    sed -i -e 's/^subjectAltName.*$/subjectAltName = DNS:www.example.com/' intermediate/openssl.cnf

Create key
----------

    openssl genrsa -out root/ca/intermediate/private/www.example.com.key.pem 2048
    chmod 400 root/ca/intermediate/private/www.example.com.key.pem

Create CSR
----------

#    openssl req -config intermediate/openssl.cnf \
#        -key intermediate/private/www.example.com.key.pem \
#        -new -sha256 -out intermediate/csr/www.example.com.csr.pem

#Put the environment in the Organizational Unit Name.  e.g. Production
#Common name needs to match the hostname used.  e.g. www.example.com for the
#above examples.

#    openssl req -new \
#        -key intermediate/private/wildcard.service.os.key.pem \
#        -reqexts SAN \
#        -config <(cat intermediate/openssl.cnf <(printf "[SAN]\nsubjectAltName=DNS:example.com,DNS:www.example.com")) \
#        -subj "/C=US/ST=Texas/O=Test Org/OU=Development/CN=test.com" \
#        -out test.csr

    # Apparently don't need SAN info in CSR, in fact it is quite useless, 
    # and/or dangerous if we actually accepted it from the CSR
    # Subject (-subj) can be anything - doesn't necessarily need to have a 
    # full DN, but it is handy for identification later
    openssl req -new \
        -key root/ca/intermediate/private/www.example.com.key.pem \
        -subj "/C=US/ST=Texas/O=Test Org/OU=Development/CN=www.example.com" \
        -out root/ca/intermediate/csr/www.example.com.csr.pem

Sign CSR / Create Cert
----------------------

#    openssl ca -config root/ca/intermediate/openssl.cnf \
#        -extensions server_cert -days 375 -notext -md sha256 \
#        -in root/ca/intermediate/csr/www.example.com.csr.pem \
#        -out root/ca/intermediate/certs/www.example.com.cert.pem
#    chmod 444 root/ca/intermediate/certs/www.example.com.cert.pem

# This signing procedure adds SAN info - be sure to update the 
# subjectAltName as appropriate
    openssl ca \
        -extensions SAN -days 375 -notext -md sha256 \
        -config <(cat root/ca/intermediate/openssl.cnf <(printf "
            [SAN]
            basicConstraints=CA:FALSE
            subjectKeyIdentifier=hash
            authorityKeyIdentifier=keyid,issuer:always
            keyUsage=critical,digitalSignature,keyEncipherment
            extendedKeyUsage=serverAuth
            subjectAltName=DNS:example.com,DNS:www.example.com \
            ")) \
        -in root/ca/intermediate/csr/www.example.com.csr.pem \
        -out root/ca/intermediate/certs/www.example.com.cert.pem
    chmod 444 root/ca/intermediate/certs/www.example.com.cert.pem

Verify Cert (optional)
----------------------

    openssl x509 -noout -text \
        -in root/ca/intermediate/certs/www.example.com.cert.pem

    openssl verify -CAfile root/ca/intermediate/certs/ca-chain.cert.pem \
        root/ca/intermediate/certs/www.example.com.cert.pem

Revoke Cert
-----------

    # You won't be able to re-issue a cert with the same DN unless you 
    # revoke the previous one
    openssl ca -config root/ca/intermediate/openssl.cnf \
        -revoke root/ca/intermediate/certs/www.example.com.cert.pem


