#!/bin/bash

# This will renew a cert already issued by this CA (for 375 days)
# First (and only) parameter should be domain name

# revoke and rename old cert
    openssl ca -config intermediate/openssl.cnf \
        -revoke intermediate/certs/$1.cert.pem

    DATE=`date '+%Y%m%d-%H%M%S'`
    mv intermediate/certs/$1.cert.pem intermediate/certs/$1.cert.pem.revoked.$DATE

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


