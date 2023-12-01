#!/bin/bash

#
# This script will install all the required packages, configure DNS, disable the swap space, 
# configure sysctl, and installs containerd.io runtime,a specific version of kubeadm, kubectl, and kubelet on all the nodes. 
# If you would like the latest version, remove the version number from the command.

## Common functions

set -exuo pipefail

#Variables

## Update the installation
sudo apt-get update && sudo apt-get upgrade -y

#fix dns: it won't be able to download images after cluster is up if this is not done
# DNS Setting
if [ ! -d /etc/systemd/resolved.conf.d ]; then
 sudo mkdir /etc/systemd/resolved.conf.d/
fi
cat <<EOF | sudo tee /etc/systemd/resolved.conf.d/dns_servers.conf
[Resolve]
DNS=${DNS_SERVERS}
EOF

sudo systemctl restart systemd-resolved

#disable swap
echo "Disabling swap"
sudo swapoff -a

# keeps the swap off during reboot
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab - || true
sudo apt-get update -y

# Install Containerd Runtime
echo "Installing containerd runtime"

# Create the .conf file to load the modules at bootup
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Set up required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

# containerd && kubernetes
echo "Adding gpg key"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "Adding docker repo"
cat <<EOF | sudo tee /etc/apt/sources.list.d/docker.list
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable
EOF
echo "Installing containerd"
sudo apt-get update && sudo apt-get install containerd.io -y
echo "Configuring containerd"
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -e 's/SystemdCgroup = false/SystemdCgroup = true/g' -i /etc/containerd/config.toml
sudo systemctl restart containerd
echo "Containerd installed successfully"

echo "Adding kubernetes repo"
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

#Kubernetes
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "Installing kubernetes"
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update 
sudo apt-get install -y kubelet="$KUBERNETES_VERSION" kubectl="$KUBERNETES_VERSION" kubeadm="$KUBERNETES_VERSION"
echo "Kubernetes installed successfully"
echo "Holding kubernetes packages"
sudo apt-mark hold kubelet kubeadm kubectl

# bash completion
sudo apt-get install bash-completion -y
echo "source <(kubectl completion bash)" >> /home/vagrant/.bashrc
