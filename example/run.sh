#!/bin/bash

# Example script to generate your certs automatically.
podName=$(kubectl get pods -l 'app=letsencrypt' -o name | sed 's/pod\///')
kubectl exec -it "$podName" /app/get-cert.sh \
  example.com \
  www.example.com \
  api.example.com

