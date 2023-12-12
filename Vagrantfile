# Author: Marco Ferretti
# Abstract: 
#   This Vagrantfile provides a way to automatically set up a Kubernetes cluster with a specified number of worker nodes, 
#   each with its own configuration, on a set of VMs.
# Description:
#   This Ruby script is a Vagrantfile, which is used to define and control virtual machine (VM) environments in a single file. 
#   This particular Vagrantfile is designed to set up a Kubernetes cluster on the VMs that Vagrant will create.
#   The script begins by loading a settings.yaml file, which presumably contains various configuration settings for the VMs and the Kubernetes cluster. 
#   It then extracts certain values from this settings file, such as the IP address of the control plane node, the number of worker nodes, 
#   and the names of the control plane and worker nodes.
#   
#   The nat function is defined to modify the network interface card (NIC) settings of a VM. Specifically, it sets the second NIC (--nic2) to use NAT 
#   networking (natnetwork) with a specific NAT network name (LFS258) and a specific NIC type (virtio).
#
#   The main configuration of the VMs is done within the Vagrant.configure("2") block. This block starts by setting up a shell provisioner 
#   that updates the VM's package lists and modifies the /etc/hosts file to include entries for the control plane and worker nodes.
#
#   The script then checks the architecture of the host machine and sets the base box for the VMs accordingly. It also enables automatic updates for 
#   the base box.
#
#   The control plane node is configured within the config.vm.define "controlplane" block. 
#   This block sets the hostname of the VM, applies the nat function to modify the NIC settings, sets up a private network with a specific IP address, 
#   and optionally sets up shared folders between the host and the VM. It also sets the number of CPUs and the amount of memory for the VM, 
#   and optionally groups the VM under a specific name. Finally, it sets up two shell provisioners that run scripts to install and configure 
#   Kubernetes and Cilium on the control plane node.
#
#   The worker nodes are configured within the (1..NUM_WORKER_NODES).each loop. This loop creates a number of worker nodes equal to NUM_WORKER_NODES, 
#   and the configuration of each worker node is similar to that of the control plane node, except that each worker node gets a unique hostname 
#   and IP address, and the second shell provisioner runs a different script.
# References: 
#   vagrant:
#     https://www.vagrantup.com/docs/vagrantfile
#   kubernetes installation:
#     https://kubernetes.io/docs/tasks/tools/
#   kubernetes on virtual box and vagrant :
#     https://blog.devops.dev/how-to-setup-kubernetes-cluster-with-vagrant-e2c808795840
#     https://devopscube.com/kubernetes-cluster-vagrant/
#   cilium installation and configuration : 
#     https://docs.cilium.io/en/stable/installation/k8s-install-helm/
#     https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/
#     https://akyriako.medium.com/install-kubernetes-1-27-with-cilium-on-ubuntu-16193c7c2ac6

require "yaml"
settings = YAML.load_file "settings.yaml"

IP_SECTIONS = settings["network"]["control_ip"].match(/^([0-9.]+\.)([^.]+)$/)
# First 3 octets including the trailing dot:
IP_NW = IP_SECTIONS.captures[0]
# Last octet excluding all dots:
IP_START = Integer(IP_SECTIONS.captures[1])
NUM_WORKER_NODES = settings["nodes"]["workers"]["count"]
MASTER_NAME = settings["nodes"]["control"]["name"]
NODE_NAME = settings["nodes"]["workers"]["name"]
$default_network_interface = `ip route | awk '/^default/ {printf "%s", $5; exit 0}'`

##trucco schifoso: vagrant usa nic1 per ssh ma per default k8s lo usa per le comunicazioni
def nat(config)
  config.vm.provider "virtualbox" do |v|
    v.customize ["modifyvm", :id, "--nic2", "natnetwork", "--nat-network2", "LFS258", "--nictype2", "virtio"]
  end
end

Vagrant.configure("2") do |config|
  config.vm.provision "shell", 
  env: { 
    "IP_NW" => IP_NW, 
    "IP_START" => IP_START, 
    "NUM_WORKER_NODES" => NUM_WORKER_NODES ,
    "MASTER_NAME" => MASTER_NAME,
    "NODE_NAME" => NODE_NAME,
    }, 
  inline: <<-SHELL
      apt-get update -y
      echo "$IP_NW$((IP_START)) ${MASTER_NAME}" >> /etc/hosts
      for i in `seq 1 ${NUM_WORKER_NODES}`; do
        echo "$IP_NW$((IP_START+i)) $NODE_NAME${i}" >> /etc/hosts
      done
  SHELL

  if `uname -m`.strip == "aarch64"
    config.vm.box = settings["software"]["box"] + "-arm64"
  else
    config.vm.box = settings["software"]["box"]
  end
  config.vm.box_check_update = true

  config.vm.define "controlplane" do |master|
    master.vm.hostname = MASTER_NAME
    nat(config)
    config.vm.network "public_network", type: "dhcp", bridge: "#$default_network_interface"
    master.vm.network "private_network", ip: settings["network"]["control_ip"]
    if settings["shared_folders"]
      settings["shared_folders"].each do |shared_folder|
        master.vm.synced_folder shared_folder["host_path"], shared_folder["vm_path"]
      end
    end
    master.vm.provider "virtualbox" do |vb|
        vb.cpus = settings["nodes"]["control"]["cpu"]
        vb.memory = settings["nodes"]["control"]["memory"]
        if settings["cluster_name"] and settings["cluster_name"] != ""
          vb.customize ["modifyvm", :id, "--groups", ("/" + settings["cluster_name"])]
        end
    end
    master.vm.provision "shell",
      env: {
        "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
        "OS" => settings["software"]["os"],
        "NET_CARD" => settings["network"]["card"],
        "DNS_SERVERS" => settings["network"]["dns_servers"].join(" "),
      },
        path: "scripts/common.sh"
    master.vm.provision "shell",
      env: {
        "CONTROL_IP" => settings["network"]["control_ip"],
        "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
        "CILIUM_VERSION" => settings["software"]["cilium"],
        "NET_CARD" => settings["network"]["card"],
      },
      path: "scripts/controlplane.sh"
  end

  (1..NUM_WORKER_NODES).each do |i|
    v_hostname=NODE_NAME+"#{i}"
    config.vm.define "node0#{i}" do |node|
      node.vm.hostname = v_hostname
      nat(config)
      node.vm.network "private_network", ip: IP_NW + "#{IP_START + i}"
      if settings["shared_folders"]
        settings["shared_folders"].each do |shared_folder|
          node.vm.synced_folder shared_folder["host_path"], shared_folder["vm_path"]
        end
      end
      node.vm.provider "virtualbox" do |vb|
          vb.cpus = settings["nodes"]["workers"]["cpu"]
          vb.memory = settings["nodes"]["workers"]["memory"]
          if settings["cluster_name"] and settings["cluster_name"] != ""
            vb.customize ["modifyvm", :id, "--groups", ("/" + settings["cluster_name"])]
          end
      end
      node.vm.provision "shell",
        env: {
          "CONTROL_IP" => settings["network"]["control_ip"],
          "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
          "CILIUM_VERSION" => settings["software"]["cilium"],
          "DNS_SERVERS" => settings["network"]["dns_servers"].join(" "),
        },
        path: "scripts/common.sh"
      node.vm.provision "shell", path: "scripts/workernode.sh"
    end

  end
end 
