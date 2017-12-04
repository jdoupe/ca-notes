#!/bin/bash

# This will make a key and cert with a 2048 bit key and signed for 375 days
# First (and only) parameter should be fqdn for site to be protected

    #openssl genrsa -out intermediate/private/$1.key.pem 2048
    openssl genpkey -algorithm RSA -aes256 -pkeyopt rsa_keygen_bits:2048 \
      -out intermediate/private/$1.key.pem
    chmod 400 intermediate/private/$1.key.pem

    # Subject (-subj) can be anything - doesn't necessarily need to have a full DN, but it is handy for identification later
    openssl req -new \
        -key intermediate/private/$1.key.pem \
        -subj "/C=US/ST=Texas/O=Test Org/OU=Development/CN=$1" \
        -out intermediate/csr/$1.csr.pem \
        -config <(printf "
          [ req ]
          string_mask = utf8only
          distinguished_name  = req_distinguished_name

          [ req_distinguished_name ]
        ")

# This signing procedure adds SAN info - be sure to update the subjectAltName as appropriate
    openssl ca \
        -extensions SAN -days 375 -notext -md sha256 \
        -in intermediate/csr/$1.csr.pem \
        -out intermediate/certs/$1.cert.pem \
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

          private_key       = intermediate/private/intermediate.key.pem
          certificate       = intermediate/certs/intermediate.cert.pem

          crlnumber         = intermediate/crlnumber
          crl               = intermediate/crl/intermediate.crl.pem
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
          subjectAltName=DNS:$1
        ")

    chmod 444 intermediate/certs/$1.cert.pem

    openssl x509 -noout -text \
        -in intermediate/certs/$1.cert.pem

    openssl verify -CAfile intermediate/certs/ca-chain.cert.pem \
        intermediate/certs/$1.cert.pem

