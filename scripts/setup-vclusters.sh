#!/bin/bash

# Script to set up and expose vclusters.
# Will create three vclusters, one for the principal, one for a managed agent, and one for an autonomous agent
# This script can easily be altered to play around with creating more agents
# It will also install and set up Argo CD Agent via helm on the vclusters
# If you change the IP range then you will need to change the IP in the values files for the agents

PRINCIPAL_CONTEXT="vcluster-principal"
MANAGED_CONTEXT="vcluster-managed"
AUTONOMOUS_CONTEXT="vcluster-autonomous"

HELM_VALUES_DIR=${HELM_VALUES_DIR:-helm}
RBAC_DIR=${RBAC_DIR:-manifests/rbac}

ARGOCD_AGENT_REF_BRANCH=${ARGOCD_AGENT_REF_BRANCH:-v0.10.0}

# Setting up each cluster follows this procedure:
# 1) Create vcluster
# 2) Create PKI for vcluster
# 3) Deploy principal or agent to the vcluster

# Create Principal vcluster
vcluster create argocd-agent-principal -n principal --kube-config-context-name "$PRINCIPAL_CONTEXT" --expose

kubectl create ns argocd --context="$PRINCIPAL_CONTEXT"

argocd-agentctl pki init \
  --principal-context "$PRINCIPAL_CONTEXT" \
  --principal-namespace argocd

argocd-agentctl pki issue principal \
  --principal-context "$PRINCIPAL_CONTEXT" \
  --principal-namespace argocd \
  --ip "127.0.0.1,$PRINCIPAL_IP"

argocd-agentctl pki issue resource-proxy \
  --principal-context "$PRINCIPAL_CONTEXT" \
  --principal-namespace argocd \
  --ip "127.0.0.1,$PRINCIPAL_IP"

argocd-agentctl jwt create-key \
  --principal-context "$PRINCIPAL_CONTEXT" \
  --principal-namespace argocd

kubectl apply -n argocd \
  --server-side \
  -k "https://github.com/argoproj-labs/argocd-agent/install/kubernetes/argo-cd/principal?ref=$ARGOCD_AGENT_REF_BRANCH" \
  --context "$PRINCIPAL_CONTEXT"

helm install argocd-agent-principal \
  oci://ghcr.io/argoproj-labs/argocd-agent/argocd-agent-principal \
  --kube-context="$PRINCIPAL_CONTEXT" \
  --namespace argocd \
  -f "${HELM_VALUES_DIR}/values-principal.yaml"

kubectl patch svc -n argocd -p '{"spec": {"type": "LoadBalancer"}}' argocd-server

kubectl patch configmap argocd-cmd-params-cm -n argocd \
  --context "$PRINCIPAL_CONTEXT" \
  --patch '{"data":{"redis.server":"argocd-agent-redis-proxy:6379"}}'

kubectl rollout restart deployment argocd-server -n argocd --context "$PRINCIPAL_CONTEXT"

argocd-agentctl agent create agent-managed \
  --principal-context "$PRINCIPAL_CONTEXT" \
  --principal-namespace argocd \
  --resource-proxy-server "${PRINCIPAL_IP}:9090"

argocd-agentctl agent create agent-autonomous \
  --principal-context "$PRINCIPAL_CONTEXT" \
  --principal-namespace argocd \
  --resource-proxy-server "${PRINCIPAL_IP}:9090"

PRINCIPAL_IP=$(kubectl get svc -n argocd --context "$PRINCIPAL_CONTEXT" argocd-agent-principal -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')

kubectl config use-context default

# Create Managed Agent vcluster
vcluster create -n managed --kube-config-context-name "$MANAGED_CONTEXT" --expose argocd-agent-managed

kubectl create ns argocd --context="$MANAGED_CONTEXT"

argocd-agentctl pki propagate \
  --principal-context "$PRINCIPAL_CONTEXT" \
  --agent-context "$MANAGED_CONTEXT" \
  --agent-namespace argocd

argocd-agentctl pki issue agent agent-managed \
  --principal-context "$PRINCIPAL_CONTEXT" \
  --agent-context "$MANAGED_CONTEXT" \
  --agent-namespace argocd

kubectl apply -n argocd \
  --server-side \
  -k "https://github.com/argoproj-labs/argocd-agent/install/kubernetes/argo-cd/agent-managed?ref=$ARGOCD_AGENT_REF_BRANCH" \
  --context "$MANAGED_CONTEXT"

helm install argocd-agent \
  oci://ghcr.io/argoproj-labs/argocd-agent/argocd-agent-agent \
  --kube-context="$MANAGED_CONTEXT" \
  --namespace argocd \
  --set "server=${PRINCIPAL_IP}"
-f "${HELM_VALUES_DIR}/values-managed.yaml"

kubectl config use-context default

# Create Autonomous Agent vcluster
vcluster create -n autonomous --kube-config-context-name "$AUTONOMOUS_CONTEXT" --expose argocd-agent-autonomous

kubectl create ns argocd --context="$AUTONOMOUS_CONTEXT"

argocd-agentctl pki propagate \
  --principal-context "$PRINCIPAL_CONTEXT" \
  --agent-context "$AUTONOMOUS_CONTEXT" \
  --agent-namespace argocd

argocd-agentctl pki issue agent agent-autonomous \
  --principal-context "$PRINCIPAL_CONTEXT" \
  --agent-context "$AUTONOMOUS_CONTEXT" \
  --agent-namespace argocd

kubectl apply -n argocd \
  --server-side \
  -k "https://github.com/argoproj-labs/argocd-agent/install/kubernetes/argo-cd/agent-autonomous?ref=$ARGOCD_AGENT_REF_BRANCH" \
  --context "$AUTONOMOUS_CONTEXT"

helm install argocd-agent \
  oci://ghcr.io/argoproj-labs/argocd-agent/argocd-agent-agent \
  --kube-context="$AUTONOMOUS_CONTEXT" \
  --namespace argocd \
  --set "server=${PRINCIPAL_IP}"
-f "${HELM_VALUES_DIR}/values-autonomous.yaml"

# Replace Agent RBAC and set secrets for resource proxy
kubectl apply -f "${RBAC_DIR}/clusterrole.yaml" --context $MANAGED_CONTEXT
kubectl apply -f "${RBAC_DIR}/clusterrole.yaml" --context $AUTONOMOUS_CONTEXT

kubectl patch secret cluster-agent-managed -n argocd \
  --context "$PRINCIPAL_CONTEXT" \
  --type='json' \
  -p='[{"op":"replace","path":"/data/server","value":"'$(echo -n "https://argocd-agent-resource-proxy.argocd.svc.cluster.local:9090?agentName=agent-managed" | base64 -w 0)'"}]'

kubectl patch secret cluster-agent-autonomous -n argocd \
  --context "$PRINCIPAL_CONTEXT" \
  --type='json' \
  -p='[{"op":"replace","path":"/data/server","value":"'$(echo -n "https://argocd-agent-resource-proxy.argocd.svc.cluster.local:9090?agentName=agent-autonomous" | base64 -w 0)'"}]'

kubectl rollout restart deployment argocd-server -n argocd \
  --context "$PRINCIPAL_CONTEXT"

kubectl config use-context default
