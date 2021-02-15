#!/bin/bash
# This script will 
# * Install all necessary tools such as Helm, Istio and Keptn CLI

#
# It requires the following ENV-Variables to be set!

K3S_VERSION="v1.19.5+k3s1"
HELM_VERSION="3.3.0"
ISTIO_VERSION="1.7.3"

echo "-----------------------------------------------------------------------"
echo "Download and install K3S"
echo "-----------------------------------------------------------------------"
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${K3S_VERSION} K3S_KUBECONFIG_MODE="644" sh -s - --no-deploy=traefik

echo "-----------------------------------------------------------------------"
echo "Set KUBECONFIG environment variable"
echo "-----------------------------------------------------------------------"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

if ! [ -x "$(command -v kubectl)" ]; then
  echo 'Error: kubectl must be installed and connected to your k8s cluster.' >&2
  exit 1
fi

echo "-----------------------------------------------------------------------"
echo "Install CURL"
echo "-----------------------------------------------------------------------"
sudo apt install curl
echo "-----------------------------------------------------------------------"
echo "Install wget"
echo "-----------------------------------------------------------------------"
sudo apt install wget
echo "-----------------------------------------------------------------------"
echo "Install zip"
echo "-----------------------------------------------------------------------"
sudo apt install zip -y
echo "-----------------------------------------------------------------------"
echo "Install jre"
echo "-----------------------------------------------------------------------"
sudo apt install default-jre -y


echo "-----------------------------------------------------------------------"
echo "Download and install helm"
echo "-----------------------------------------------------------------------"
wget https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz
tar -zxvf helm-v${HELM_VERSION}-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm

# remove downloaded files
rm helm-v${HELM_VERSION}-linux-amd64.tar.gz
rm -r linux-amd64

echo "-----------------------------------------------------------------------"
echo "Download and install keptn CLI"
echo "-----------------------------------------------------------------------"
#install keptn cli
curl -sL https://get.keptn.sh | sudo -E bash

echo "-----------------------------------------------------------------------"
echo "Download and install instio"
echo "-----------------------------------------------------------------------"
#install istio
ISTIO_EXISTS=$(kubectl get po -n istio-system | grep Running | wc | awk '{ print $1 }')
if [[ "$ISTIO_EXISTS" -gt "0" ]]
then
  echo "Istio already installed on k8s"
else
  echo "Downloading and installing Istio ${ISTIO_VERSION}"
  curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -
  sudo mv istio-${ISTIO_VERSION}/bin/istioctl /usr/local/bin/istioctl

  istioctl install -y
fi

INGRESS_HOST=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')