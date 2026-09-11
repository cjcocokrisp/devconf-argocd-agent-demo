#!/bin/bash

# Script that install metallb
# Installs metallb to the metallb-system namespace but that can be set with the METALLB_NS env variable
# An IPAddressPool and L2Advirtisement are created as well and the IP range can be set with the enviroment
# variable METALLB_IPRANGE if not it defaults to 192.168.1.200-192.168.1.250

set -oex pipefail

METALLB_NS="${METALLB_NS:-metallb-system}"
METALLB_IPRANGE="${METALLB_IPRANGE:-192.168.1.200-192.168.1.250}"

helm repo add metallb https://metallb.github.io/metallb
helm repo update
helm install metallb metallb/metallb --namespace $METALLB_NS --create-namespace --wait

kubectl create -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: argocd-agent-pool
  namespace: $METALLB_NS
spec:
  addresses:
  - $METALLB_IPRANGE
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: argocd-agent-l2-advert
  namespace: $METALLB_NS
spec:
  ipAddressPools:
  - production-pool
EOF
