#!/bin/bash

# Script to install packages that are needed to run this demo
# This assumes that you are using Fedora so if you plan to use this pass the environment variable
# PKG_MANAGER with the install command of your choice.
# Packages may also differ in your package manager so if that is the case a PKGS environment variable
# can be passed to edit the packages installed
# You can also set the version to install for the following tools and corresponds to the variables below
# The defaults are from the time of this demo
# Argo CD CLI | ARGOCD_VERSION | v3.5.2
# Argo CD Agent CLI | ARGOCD_AGENT_VERSION | v0.10.0
# vcluster CLI | VCLUSTER_VERSION | v0.36.1
# This script should be run as root unless you have permissions to install things with your package managenr
# and write to /usr/local/bin

set -oex pipefail

ARGOCD_VERSION="${ARGOCD_VERSION:-v3.5.2}"
ARGOCD_AGENT_VERSION="${ARGOCD_AGENT_VERSION:-v0.10.0}"
VCLUSTER_VERSION="${VCLUSTER_VERSION:-v0.36.1}"
PKG_MANAGER="${PKG_MANAGER:-dnf install -y}"
PKGS="${PKGS:-tmux vim git kubectl helm k9s}"

# Install packages from package manager
$PKG_MANAGER $PKGS

# CPU Arch is needed for the argocd binaries
ARCH="$(uname -m)"
if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  ARCH="arm64"
else
  ARCH="amd64"
fi

# Install Argo CD CLI, Argo CD Agent CLI, vcluster, and k3s
curl -Lo argocd "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-$ARCH"
chmod +x argocd
mv argocd /usr/local/bin/

curl -Lo argocd-agentctl "https://github.com/argoproj-labs/argocd-agent/releases/latest/download/argocd-agentctl-linux-$ARCH"
chmod +x argocd-agentctl
mv argocd-agentctl /usr/local/bin/

curl -L -o vcluster "https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-linux-$ARCH"
chmod +x vcluster
mv vcluster /usr/local/bin/

curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_ENABLE=true INSTALL_K3S_SKIP_START=true sh -
