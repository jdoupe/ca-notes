#References
#----------
#OpenSSL
#https://jamielinux.com/docs/openssl-certificate-authority/

#Vault
#http://cuddletech.com/?p=959
#http://marsdominion.com/2016/10/26/using-vault-as-a-certificate-authority/
#https://blog.kintoandar.com/2015/11/vault-PKI-made-easy.html
#https://www.vaultproject.io/docs/index.html

#Create root pair
#----------------

# Set up directory structure and pertinent files
mkdir -p root/certs root/crl root/newcerts root/private
chmod 700 root/private
touch root/index.txt
echo 1000 > root/serial

#Create root key
#---------------

#openssl genrsa -aes256 -out root/private/ca.key.pem 4096
#openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out root/private/ca.key.pem
# OR NON-RSA?
# This one embeds param info in key, and won't generate a proper cert
# openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:secp521r1 -out root/private/ca.key.pem
# This one does it "right", but does a pipe for some silly reason
# openssl ecparam -genkey -name secp384r1 | openssl ec -out root/private/ca.key.pem
# This seems to be the most straightforward way
# openssl ecparam -name secp521r1 -genkey -noout -out root/private/ca.key.pem

# For ECC keys, I'm using secp521r1 for both the root and intermediate ca certs, and secp384r1 for server keys.
# Other options can be found by running `openssl ecparam -list_curves`

# I've now found the "right" way (using "genpkey"), thanks to some hints from https://gist.github.com/briansmith/2ee42439923d8e65a266994d0f70180b
openssl genpkey -algorithm EC \
    -pkeyopt ec_paramgen_curve:secp521r1 \
    -pkeyopt ec_param_enc:named_curve \
    -out root/private/ca.key.pem

chmod 400 root/private/ca.key.pem

#Create root certificate
#-----------------------
# The below command creates a self-signed cert (-x509 parameter)
# The need for a "distinguished_name" option is apparently a bug that
# no one cares to fix.  (Note the empty section).
# There isn't a way (that I have found) to specify x509_extensions from
# the command line.

openssl req \
  -key root/private/ca.key.pem \
  -new -x509 -days 7300 -sha256 -extensions v3_ca \
  -out root/certs/ca.cert.pem \
  -subj "/C=US/ST=Texas/O=Test Org/CN=Test Org Root CA" \
  -config <(printf "
    [ req ]
    distinguished_name  = req_distinguished_name
    x509_extensions = v3_ca

    [ req_distinguished_name ]

    [ v3_ca ]
    subjectKeyIdentifier = hash
    authorityKeyIdentifier = keyid:always,issuer
    basicConstraints = critical, CA:true
    keyUsage = critical, digitalSignature, cRLSign, keyCertSign
  ")

chmod 444 root/certs/ca.cert.pem

#Verify root certificate
#-----------------------

openssl x509 -noout -text -in root/certs/ca.cert.pem

#Create intermediate pair
#------------------------

# Set up directory structure and pertinent files
mkdir -p intermediate/certs intermediate/crl intermediate/csr intermediate/newcerts intermediate/private
chmod 700 intermediate/private
touch intermediate/index.txt
echo 1000 > intermediate/serial
echo 1000 > intermediate/crlnumber

#Create intermediate key
#-----------------------

#openssl genrsa -aes256 -out intermediate/private/intermediate.key.pem 4096
#openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 \
#  -out intermediate/private/intermediate.key.pem
#openssl ecparam -name secp521r1 -genkey -noout -out intermediate/private/intermediate.key.pem
openssl genpkey -algorithm EC \
    -pkeyopt ec_paramgen_curve:secp521r1 \
    -pkeyopt ec_param_enc:named_curve \
    -out intermediate/private/intermediate-ca.key.pem
chmod 400 intermediate/private/intermediate-ca.key.pem

#Create intermediate certificate
#-------------------------------
# Note the config section is exactly the same as for the root certificate, however
# the command lacks the -x509 option.  This creates a CSR which then needs to be
# signed by the root certificate (a la the "ca" command following).

# The config for the "ca" command is a bit larger, and defines file locations
# for the root CA.

openssl req -new -sha256 \
  -key intermediate/private/intermediate-ca.key.pem \
  -out intermediate/csr/intermediate-ca.csr.pem \
  -subj "/C=US/ST=Texas/O=Test Org/CN=Test Org Intermediate CA" \
  -config <(printf "
    [ req ]
    distinguished_name  = req_distinguished_name
    x509_extensions = v3_ca

    [ req_distinguished_name ]

    [ v3_ca ]
    subjectKeyIdentifier = hash
    authorityKeyIdentifier = keyid:always,issuer
    basicConstraints = critical, CA:true
    keyUsage = critical, digitalSignature, cRLSign, keyCertSign
  ")

openssl ca -extensions v3_intermediate_ca \
  -days 3650 -notext -md sha256 \
  -in intermediate/csr/intermediate-ca.csr.pem \
  -out intermediate/certs/intermediate-ca.cert.pem \
  -config <(printf "
    [ ca ]
    default_ca = CA_default

    [ CA_default ]
    dir               = root
    certs             = root/certs
    crl_dir           = root/crl
    new_certs_dir     = root/newcerts
    database          = root/index.txt
    serial            = root/serial
    RANDFILE          = root/private/.rand

    private_key       = root/private/ca.key.pem
    certificate       = root/certs/ca.cert.pem

    crlnumber         = root/crlnumber
    crl               = root/crl/ca.crl.pem
    crl_extensions    = crl_ext
    default_crl_days  = 30

    name_opt          = ca_default
    cert_opt          = ca_default
    default_days      = 375
    preserve          = no
    policy            = policy_strict

    [ policy_strict ]
    countryName             = match
    stateOrProvinceName     = match
    organizationName        = match
    organizationalUnitName  = optional
    commonName              = supplied
    emailAddress            = optional

    [ crl_ext ]
    authorityKeyIdentifier=keyid:always

    [ v3_intermediate_ca ]
    subjectKeyIdentifier = hash
    authorityKeyIdentifier = keyid:always,issuer
    basicConstraints = critical, CA:true, pathlen:0
    keyUsage = critical, digitalSignature, cRLSign, keyCertSign
  ")

chmod 444 intermediate/certs/intermediate-ca.cert.pem

#Verify intermediate certificate
#-------------------------------

openssl x509 -noout -text -in intermediate/certs/intermediate-ca.cert.pem

#Create key
#----------

#    openssl genrsa -out intermediate/private/www.example.com.key.pem 2048
#openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
#  -out intermediate/private/www.example.com.key.pem
#openssl ecparam -name secp384r1 -genkey -noout -out intermediate/private/www.example.com.key.pem
openssl genpkey -algorithm EC \
    -pkeyopt ec_paramgen_curve:secp384r1 \
    -pkeyopt ec_param_enc:named_curve \
    -out intermediate/private/www.example.com.key.pem

    chmod 400 intermediate/private/www.example.com.key.pem

#Create CSR
#----------

    openssl req -new \
        -key intermediate/private/www.example.com.key.pem \
        -subj "/C=US/ST=Texas/O=Test Org/OU=Development/CN=www.example.com" \
        -out intermediate/csr/www.example.com.csr.pem \
        -config <(printf "
          [ req ]
          string_mask = utf8only
          distinguished_name  = req_distinguished_name

          [ req_distinguished_name ]
        ")

#Sign CSR / Create Cert
#----------------------
# Note this config section specifies the file/path locations for the
# intermediate CA which should be used to sign any issued certificates.
# You'll also want to note that subjectAltName for the certificate is
# defined in the [SAN] section.  Instead of having this huge config
# specified on the command line, it may be worthwhile to move all but
# [SAN] section to an actual file (intermediate-ca.cnf), and wrap the
# printf with something like <(cat intermediate-ca.cnf <(printf ... ))

    openssl ca \
        -extensions SAN \
        -days 375 \
        -notext \
        -md sha256 \
        -in intermediate/csr/www.example.com.csr.pem \
        -out intermediate/certs/www.example.com.cert.pem \
        -config <(printf "
          [ ca ]
          default_ca = CA_default

          [ CA_default ]
          dir               = intermediate
          certs             = intermediate/certs
          crl_dir           = intermediate/crl
          new_certs_dir     = intermediate/newcerts
          database          = intermediate/index.txt
          serial            = intermediate/serial
          RANDFILE          = intermediate/private/.rand

          private_key       = intermediate/private/intermediate-ca.key.pem
          certificate       = intermediate/certs/intermediate-ca.cert.pem

          crlnumber         = intermediate/crlnumber
          crl               = intermediate/crl/intermediate-ca.crl.pem
          crl_extensions    = crl_ext
          default_crl_days  = 30

          name_opt          = ca_default
          cert_opt          = ca_default
          preserve          = no
          policy            = policy_loose

          [ policy_loose ]
          countryName             = optional
          stateOrProvinceName     = optional
          localityName            = optional
          organizationName        = optional
          organizationalUnitName  = optional
          commonName              = supplied
          emailAddress            = optional

          [ crl_ext ]
          authorityKeyIdentifier=keyid:always

          [SAN]
          basicConstraints=CA:FALSE
          subjectKeyIdentifier=hash
          authorityKeyIdentifier=keyid,issuer:always
          keyUsage=critical,digitalSignature,keyEncipherment
          extendedKeyUsage=serverAuth
          subjectAltName=DNS:example.com,DNS:www.example.com
        ") 

    chmod 444 intermediate/certs/www.example.com.cert.pem

# Consider keyAgreement and nonRepudiation as keyUsage additions?

#Verify Cert (optional)
#----------------------

    openssl x509 -noout -text \
        -in intermediate/certs/www.example.com.cert.pem

    # Create CA chain
    cat intermediate/certs/intermediate-ca.cert.pem root/certs/ca.cert.pem > intermediate/certs/ca-chain.cert.pem

    openssl verify -CAfile intermediate/certs/ca-chain.cert.pem \
        intermediate/certs/www.example.com.cert.pem

#Revoke Cert
#-----------

    # You won't be able to re-issue a cert with the same DN unless you 
    # revoke the previous one
#    openssl ca -config intermediate/openssl.cnf \
#        -revoke intermediate/certs/www.example.com.cert.pem

