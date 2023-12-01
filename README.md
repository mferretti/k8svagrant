# Kubernetes Cluster with Cilium CNI with Vagrant and Virtualbox

## Abstract
This Vagrantfile provides a way to automatically set up a Kubernetes cluster with a specified number of worker nodes, each with its own configuration, on a set of VMs.

## Prerequisites
[Vagrant](https://www.vagrantup.com/) and [VirtualBox](https://www.virtualbox.org/) are installed

## Description
This Ruby script is a Vagrantfile, which is used to define and control virtual machine (VM) environments in a single file. This particular Vagrantfile is designed to set up a Kubernetes cluster on the VMs that Vagrant will create.

The script begins by loading a `settings.yaml` file, which presumably contains various configuration settings for the VMs and the Kubernetes cluster. It then extracts certain values from this settings file, such as the IP address of the control plane node, the number of worker nodes, and the names of the control plane and worker nodes.

The `nat` function is defined to modify the network interface card (NIC) settings of a VM. Specifically, it sets the second NIC (`--nic2`) to use NAT networking (`natnetwork`) with a specific NAT network name (`LFS258`) and a specific NIC type (`virtio`).

The main configuration of the VMs is done within the `Vagrant.configure("2")` block. This block starts by setting up a shell provisioner that updates the VM's package lists and modifies the `/etc/hosts` file to include entries for the control plane and worker nodes.

The script then checks the architecture of the host machine and sets the base box for the VMs accordingly. It also enables automatic updates for the base box.

The control plane node is configured within the `config.vm.define "controlplane"` block. This block sets the hostname of the VM, applies the `nat` function to modify the NIC settings, sets up a private network with a specific IP address, and optionally sets up shared folders between the host and the VM. It also sets the number of CPUs and the amount of memory for the VM, and optionally groups the VM under a specific name. Finally, it sets up two shell provisioners that run scripts to install and configure Kubernetes and Cilium on the control plane node.

The worker nodes are configured within the `(1..NUM_WORKER_NODES).each` loop. This loop creates a number of worker nodes equal to `NUM_WORKER_NODES`, and the configuration of each worker node is similar to that of the control plane node, except that each worker node gets a unique hostname and IP address, and the second shell provisioner runs a different script.

## References
- [Vagrant](https://www.vagrantup.com/docs/vagrantfile)
- [Kubernetes Installation](https://kubernetes.io/docs/tasks/tools/)
- [Kubernetes on Virtual Box and Vagrant](https://blog.devops.dev/how-to-setup-kubernetes-cluster-with-vagrant-e2c808795840)
- [Kubernetes Cluster Vagrant](https://devopscube.com/kubernetes-cluster-vagrant/)
- [Cilium Installation and Configuration](https://docs.cilium.io/en/stable/installation/k8s-install-helm/)
- [Cilium Getting Started](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/)
- [Install Kubernetes 1.27 with Cilium on Ubuntu](https://akyriako.medium.com/install-kubernetes-1-27-with-cilium-on-ubuntu-16193c7c2ac6)