#!/bin/bash
#
# Setup for Control Plane (Master) servers

set -euxo pipefail

NODENAME=$(hostname -s)

# For Vagrant re-runs, check if there is existing configs in the location and delete it for saving new configuration.
echo "Checking if there is existing configs in the location and delete it for saving new configuration."
config_path="/vagrant/configs"

if [ -d $config_path ]; then
  rm -f $config_path/*
else
  mkdir -p $config_path
fi

sudo kubeadm config images pull

echo "Preflight Check Passed: Downloaded All Required Images"


#Install Cilium network plugin
echo "Configuring Cilium network plugin"
## Update the installation
#sudo apt-get install -y jq 
sudo snap install yq && sudo snap install helm --classic
helm repo add cilium https://helm.cilium.io/
helm template cilium cilium/cilium --version ${CILIUM_VERSION} --namespace kube-system > $config_path/cilium-cni.yaml
echo "Extracting pod subnet"
PODSUBNET=$(cat $config_path/cilium-cni.yaml | grep .cluster-pool-ipv4-cidr | yq e '.cluster-pool-ipv4-cidr')
echo "Getting kubernetes package version"
VERSION="$(echo ${KUBERNETES_VERSION} | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
sudo rm  $config_path/cilium-cni.yaml

#Preparing for kubeadm init

sudo systemctl enable kubelet
 kubeadm init \
  --pod-network-cidr=$PODSUBNET \
  --skip-phases=addon/kube-proxy \
  --control-plane-endpoint $CONTROL_IP \

mkdir -p "$HOME"/.kube
sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config


cp -i /etc/kubernetes/admin.conf $config_path/config
touch $config_path/join.sh
chmod +x $config_path/join.sh

sudo -i -u vagrant bash << EOF
whoami
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
EOF

echo "Environment=\"KUBELET_EXTRA_ARGS=--node-ip=$CONTROL_IP\"" | sudo tee -a /etc/systemd/system/kubelet.service.d/10-kubeadm.conf


## Generate join command
kubeadm token create --print-join-command > $config_path/join.sh

#Deploy Cilium
echo "Deploying Cilium"
CLI_ARCH=amd64
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/master/stable.txt)

if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sudo cilium install --version ${CILIUM_VERSION}

#enable hubble
sudo cilium hubble enable


echo "Kubernetes Control Plane setup complete"
#Cleanup extra packages
echo "Cleaning up extra packages"
sudo apt-get autoremove -y
sudo apt-get clean
sudo snap remove helm yq

