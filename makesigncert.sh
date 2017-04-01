#!/bin/bash

# This will make a key and cert with a 2048 bit key and signed for 375 days
# First (and only) parameter should be domain name

#    cd test-ca
    openssl genrsa -out intermediate/private/$1.key.pem 2048
    chmod 400 intermediate/private/$1.key.pem

    # Apparently don't need SAN info in CSR, in fact it is quite useless, and/or dangerous if we actually accepted it from the CSR
    # Subject (-subj) can be anything - doesn't necessarily need to have a full DN, but it is handy for identification later
    openssl req -new \
        -key intermediate/private/$1.key.pem \
        -subj "/C=US/ST=Texas/O=Test Org/OU=Development/CN=$1" \
        -out intermediate/csr/$1.csr.pem

# This signing procedure adds SAN info - be sure to update the subjectAltName as appropriate
    openssl ca \
        -extensions SAN -days 375 -notext -md sha256 \
        -config <(cat intermediate/openssl.cnf <(printf "
            [SAN]
            basicConstraints=CA:FALSE
            subjectKeyIdentifier=hash
            authorityKeyIdentifier=keyid,issuer:always
            keyUsage=critical,digitalSignature,keyEncipherment
            extendedKeyUsage=serverAuth
            subjectAltName=DNS:$1
            ")) \
        -in intermediate/csr/$1.csr.pem \
        -out intermediate/certs/$1.cert.pem
    chmod 444 intermediate/certs/$1.cert.pem

    openssl x509 -noout -text \
        -in intermediate/certs/$1.cert.pem

    openssl verify -CAfile intermediate/certs/ca-chain.cert.pem \
        intermediate/certs/$1.cert.pem

