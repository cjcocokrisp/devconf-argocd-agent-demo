#!/bin/bash

# Script to setup k3s
# This script will set up and enable k3s it will also copy the kubeconfig
# into .kube. You can specify the path the kubeconfig is copied to by providing
# the environment variable KUBECONFIG_PATH
# Script will need to be run as root unless you have permissions to run systemctl

set -oex pipefail

KUBECONFIG_PATH="${KUBECONFIG_PATH:-/home/${SUDO_USER:-$USER}/.kube/config}"

# Disable servicelb because we need to use metallb to allow the clusters to talk to each other
echo "    --disable=servicelb" >>/etc/systemd/system/k3s.service

# Enable k3s and copy kubeconfig
systemctl enable --now k3s

mkdir -p $(dirname "$KUBECONFIG_PATH")
cp /etc/rancher/k3s/k3s.yaml "$KUBECONFIG_PATH"

if [[ -n "$SUDO_USER" ]]; then
  USER="$SUDO_USER"
fi

chown "$USER":"$USER" "$KUBECONFIG_PATH"
