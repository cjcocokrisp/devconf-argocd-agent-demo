## devconf-argocd-agent-demo

This repository contains resources for the demo included in the DevConf 2026 talk: Argo CD Agent: Redefining Multi-Cluster GitOps.
The goal of this repository is to provide an easy way to set up an environment where Argo CD Agent is deployed to play around with
the project. There is also an example application for both managed and autonomous agents that deploys an nginx server
with an emulatorjs webpage that loads the homebrew GBA rom [Apotris](https://hh.gbdev.io/game/apotris).

The setup uses [K3s](https://k3s.io/) as the Kubernetes distribution and [MetalLB](https://metallb.io/) as a load balancer. 
You can use any distribution as long as you have a load balancer. As multiple clusters are needed, 
[VCluster](https://www.vcluster.com/) is used to create virtual clusters inside of the main K3s host.

Any Linux distribution can be used for this test as well but it was built to be used on Fedora. If you choose to pick a
different distro you will need to update some of the scripts, most notably the dependency install script to use your distro's
package manager (environment variables can be set to adjust this).

### Directory Map

```
.
├── helm                             # Helm values for each Argo CD Agent component
│   ├── values-autonomous.yaml
│   ├── values-managed.yaml
│   └── values-principal.yaml
├── manifests                        # Manifests for various Kubernetes resources used in the demo 
│   ├── apps                         # Applications to be deployed on the agents
│   │   ├── autonomous-app.yaml
│   │   ├── autonomous-proj.yaml
│   │   └── managed-app.yaml
│   ├── rbac                         # ClusterRole to replace default that is deployed on Agents for UI resource viewing
│   │   └── clusterrole.yaml
│   └── resources                    # Kubernetes resources deployed by example applications
│       ├── configmap.yaml
│       ├── deployment.yaml
│       └── service.yaml
└── scripts                          # Useful scripts that can be used to automate setup
    ├── install-deps.sh
    ├── setup-k3s.sh
    ├── setup-metallb.sh
    └── setup-vclusters.sh
```

### Setup Guide

This section will explain how to get the demo up and running from scratch. It will cover setting up the Argo CD Agent
deployment and the example applications.

#### Step 1: Setup system to run demo on

The first step is to setup a Linux host of any distro of your choice. This guide will be assuming Fedora but after the
installing dependency step the distro should not matter.

If using Fedora, the following rules must be added to the firewall to make the K3s metric server work.
```bash 
sudo firewall-cmd --zone=trusted --add-interface=cni0 --permanent
sudo firewall-cmd --zone=trusted --add-interface=flannel.1 --permanent
sudo firewall-cmd --zone=trusted --add-port=10250/tcp --permanent
```

#### Step 2: Installing dependencies

Certain dependencies must be installed to run the demo as well.

The bare minimum needed are `kubectl`, `helm`, `argocd-agentctl`, and `vcluster`. The following script can be ran to
install it for you along with a few other nice to have tools like `k9s`.

```bash
# See the scripts header for environment variables that can be adjusted for different settings
# The script must be run as root unless you have permissions to download packages
sudo ./scripts/install-deps.sh
```

#### Step 3: Setting up K3s

With the dependencies installed the next step is to get K3s up and running. You just need to enable its service and copy the
kubeconfig to your home directory. This also can be done with the automated script.

```bash
# The script must be run as root unless you have access to copy from /etc/ and run systemctl
sudo ./scripts/setup-k3s.sh
```

#### Step 4: Setting up Load Balancer

The next step would be to install the load balancer. The example uses MetalLB, but any load balancer can be used. I recommend
to install MetalLB through helm. A script is included that deploys MetalLB through helm and then configures an IPAddressPool
and L2Advertisement so it can begin to serve IPs.

```bash
# If for some reason you need a different IP range from 192.168.1.200 - 192.168.1.250. See the header comments on the script
# to learn how to configure that
./scripts/setup-metallb.sh
```

#### Step 5: Setup vclusters

This step involves setting up the vclusters and deploying Argo CD Agent. Make sure you are in the default context when
creating the vclusters. You should not be nesting vclusters.

What is done of each vcluster follows the following steps:
1) Create the vcluster and have it get an IP
2) Create PKI for the vcluster's Argo CD Agent deployment
3) Deploy Argo CD components for that cluster
4) Deploy the Argo CD Agent component for targeted cluster

These steps are very true to the Argo CD Agent [installation guide](https://argocd-agent.readthedocs.io/stable/getting-started/) 
in the docs.

Some other stuff is done per component:

Principal:
- Argo CD Server and Principal are deployed before PKI is init to get the IP of the principal service
- Namespace for the autonomous agent is created
- Argo CD server is patched to use the LoadBalancer

Autonomous Agent:
- Argo CD Default ClusterRole is patched to now have the subject in the `agent-autonomous` namespace

Both Agents:
- Agent ClusterRole is updated to allow CRUD operations on common Kubernetes resources to allow for the resource proxy to
function properly when accessed through the Argo CD UI
- Cluster secrets for both agents on principal are patched to target the resource proxy service instead of the IP


As the other steps in the demo there is a script to automate this.

```bash
./scripts/setup-vclusters.sh
```

#### Step 6: Verifying everything is connected

Once the vclusters are setup, verify that the agents are connected to the principal by opening up the principals logs and
checking if you see the following message for both of the agents like below.
```
level=info msg="Updated connection status to 'Successful' in Cluster: 'agent-managed'"
level=info msg="Updated connection status to 'Successful' in Cluster: 'agent-autonomous'" 
```

To access the Argo CD UI or connect with the Argo CD CLI, if you ran the script check the service for the Argo CD server 
and you should have the IP for the server. The initial admin password can be retrieved from the `argocd-initial-admin-secret`
secret.

#### Step 7: Deploy example applications

The final step is to deploy the test applications. 

```bash
# Deploy managed app 
kubectl apply -f ./manifests/apps/managed-app.yaml --context vcluster-principal
# To deploy the autonomous app you also need to deploy the app project
kubectl apply -f ./manifests/apps/autonomous-proj.yaml --context vcluster-autonomous
kubectl apply -f ./manifests/apps/autonomous-app.yaml --context vcluster-autonomous
```

#### Teardown

To remove everything from the Kubernetes cluster the vclusters just need to be deleted. Make sure that you are in the default
context when you delete them.

```
vcluster delete argocd-agent-principal
vcluster delete argocd-agent-managed
vcluster delete argocd-agent-autonomous
```

### Issues

If you encounter any issues running this demo please open a GitHub issue for it with the error information and a description
of the problem you're facing.
