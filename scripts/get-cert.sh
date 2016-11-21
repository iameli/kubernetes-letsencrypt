#!/bin/bash
#
# Adapted from Thomas Pircher's Let's Encrypt Manual Mode script:
# https://www.tty1.net/blog/2015/using-letsencrypt-in-manual-mode_en.html
# Redistributed under a Creative Commons Attribution-Share Alike 3.0 Unported License
#
# To use Let's Encrypt, you must read the TOS at https://letsencrypt.org/documents/LE-SA-v1.0.1-July-27-2015.pdf and
# acknowledge your agreement by setting the "tos" environment variable to "true"
#
# This thing has lots of environment variables:
# Required:
#    tos
#    country
#    state
#    town
#    organization
#    email
#    secretName
#  Optional:
#    acmeServer - Set to https://acme-staging.api.letsencrypt.org/directory if you'd like to generate a testing cert
#    namespace - Default "default"

set -o errexit
set -o nounset
set -o pipefail

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Set up optional parameters
acmeServer="${acmeServer:-https://acme-v01.api.letsencrypt.org/directory}"
namespace="${namespace:-default}"

# Constants
key="key.pem"
csr="signreq.der"
newSecretFile="newsecret.yml"
rawDomains=$*

function log() {
  echo ""
  echo "================================================="
  echo "kubernetes-letsencrypt: $1"
  echo "================================================="
  echo ""
}

function encodeFile() {
  cat "$1" | base64 --wrap=0
}

if [ "${tos:-}" != "true" ] ; then
  echo 'Error: you must agree to the terms of service and set tos="true"'
  exit 1
fi

if [ $# -lt 1 ]; then
  echo "$0: error: at least one domain name required."
  exit 1
fi
domain=$1

shift
other_domains=
while [ $# -gt 0 ]; do
  other_domains="$other_domains,DNS:$1"
  shift
done

tmpdir=
cleanup() {
  if [ -n "$tmpdir" -a -d "$tmpdir" ]; then
    rm -rf "$tmpdir"
  fi
}
trap cleanup INT QUIT TERM EXIT
tmpdir=`mktemp -d -t mkcert-XXXXXXX`

sslcnf="$tmpdir/openssl.cnf"
cat /etc/ssl/openssl.cnf > "$sslcnf"
echo "[SAN]" >> "$sslcnf"
echo "subjectAltName=DNS:$domain$other_domains" >> "$sslcnf"

# You can only request so many certs from letsencrypt before they stop giving them to you. As such, let's do a quick
# Kubernetes sanity check before we go talk to them -- that way if this pod's configuration is broken we won't use up
# one of our cert generations.
log "Doing Kubernetes sanity check"
kubectl --namespace="$namespace" get pods > /dev/null || (
  log "Error!"
  echo "Unable to communicate with Kubernetes. Check to make sure you are in a cluster and your serviceaccount token"
  echo "is configured properly."
  exit 1
)

log "Generating key and CSR"
openssl req \
  -new -newkey rsa:2048 -sha256 -nodes \
  -keyout "$key" -out "$csr" -outform der \
  -subj "/C=$country/ST=$state/L=$town/O=$domain/emailAddress=$email/CN=$domain" \
  -reqexts SAN \
  -config "$sslcnf"

log "Retrieving new cert with letsencrypt"
certbot certonly \
  --server "$acmeServer" \
  --text \
  --agree-tos \
  --config-dir letsencrypt/etc \
  --logs-dir letsencrypt/log \
  --work-dir letsencrypt/lib \
  --email "$email" \
  --csr "$csr" \
  --authenticator webroot \
  --webroot-path "/webroot"

log "Generating secret"
(cat << EOF
apiVersion: v1
kind: Secret
metadata:
  name: "$secretName"
  namespace: "$namespace"
type: Opaque
data:
  key.pem: "$(encodeFile key.pem)"
  cert.pem: "$(encodeFile 0000_cert.pem)"
  chain.pem: "$(encodeFile 0000_chain.pem)"
  certchain.pem: "$(encodeFile 0001_chain.pem)"
EOF
) > "$newSecretFile"
echo "Done!"

kubectl get -f "$newSecretFile" > /dev/null && (
  log "Secret exists, running kubectl apply"
  kubectl apply -f "$newSecretFile"
) || (
  log "Secret does not exist, running kubectl create"
  kubectl create -f "$newSecretFile"
)

rm -rf $DIR/*.pem
rm -rf $DIR/*.der
rm -rf $DIR/*.yml

log "Done!"
