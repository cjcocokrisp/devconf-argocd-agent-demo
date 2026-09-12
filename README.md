# devconf-argocd-agent-demo

Deemo for DevConf.US 2026 Talk - Argo CD Agent: Redefining Multi-Cluster GitOps

Firewall Adjustments
sudo firewall-cmd --zone=trusted --add-interface=cni0 --permanent
sudo firewall-cmd --zone=trusted --add-interface=flannel.1 --permanent
sudo firewall-cmd --zone=trusted --add-port=10250/tcp --permanent
