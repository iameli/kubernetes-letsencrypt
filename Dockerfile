FROM quay.io/letsencrypt/letsencrypt

MAINTAINER Eli Mallon <eli@iame.li>

ENV KUBE_LATEST_VERSION="v1.4.6"
ENV KUBE_URL="https://github.com/kubernetes/kubernetes/releases/download/${KUBE_LATEST_VERSION}/kubernetes.tar.gz"

# No curl or wget -- what the hey, let's just download kubernetes with a python one-liner.
RUN cd /usr/bin && \
  python -c "from urllib import urlretrieve; urlretrieve('$KUBE_URL', 'kubernetes-latest.tar.gz')" && \
  tar xzf kubernetes-latest.tar.gz && \
  mv kubernetes/platforms/linux/amd64/kubectl ./kubectl && \
  rm -rf ./kubernetes-latest.tar.gz ./kubernetes && \
  mkdir /webroot

WORKDIR /app
ADD scripts/get-cert.sh /app/get-cert.sh
ADD scripts/entrypoint.sh /app/entrypoint.sh

# Start up the HTTP server at our webroot.
ENTRYPOINT ["/app/entrypoint.sh"]
