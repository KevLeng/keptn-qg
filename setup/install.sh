#!/bin/bash
# This script will 
# * Install all necessary tools such as Helm, Istio and Keptn CLI
#
# It requires the following ENV-Variables to be set!

K3S_VERSION="v1.19.5+k3s1"
HELM_VERSION="3.3.0"
ISTIO_VERSION="1.7.3"
KEPTN_VERSION="0.7.3"
REPO="https://github.com/KevLeng/keptn-qg.git"
REPO_RELEASE="main"
REPO_DIR="~/keptn-qg"

DT_TENANT=${DT_TENANT:-none}
DT_API_TOKEN=${DT_API_TOKEN:-none}
DT_PAAS_TOKEN=${DT_PAAS_TOKEN:-none}

TENANT=${TENANT:-none}
APITOKEN=${APITOKEN:-none}



create_default_project=true
create_customer_project=true

if [[ "$DT_TENANT" == "none" ]]; then
  if [[ "$TENANT" != "none" ]]; then
    DT_TENANT=${TENANT}
  else
    echo "You have to set DT_TENANT to your Tenant URL, e.g: abc12345.dynatrace.live.com or yourdynatracemanaged.com/e/abcde-123123-asdfa-1231231"
    echo "To learn more about the required settings please visit https://keptn.sh/docs/0.7.x/monitoring/dynatrace/install"
    exit 1
  fi
fi

if [[ "$DT_TENANT" == "http://"* ]]; then
        DT_TENANT=${DT_TENANT:7}
        echo "DT_TENANT was set starting with http://, removing. DT_TENANT is now ${DT_TENANT}"
elif [[ "$DT_TENANT" == "https://"* ]]; then
        DT_TENANT=${DT_TENANT:8}
        echo "DT_TENANT was set starting with http:s//, removing. DT_TENANT is now ${DT_TENANT}"
fi

if [[ "$DT_API_TOKEN" == "none" ]]; then
    if [[ "$APITOKEN" != "none" ]]; then
      DT_API_TOKEN=${APITOKEN}
    else
      echo "You have to set DT_API_TOKEN to a Token that has read/write configuration, access metrics, log content and capture request data priviliges"
      echo "If you want to learn more please visit https://keptn.sh/docs/0.7.x/monitoring/dynatrace/install"
      exit 1
    fi
fi

echo "-----------------------------------------------------------------------"
echo "DT_TENANT=${DT_TENANT}"
echo "DT_API_TOKEN=${DT_API_TOKEN}"
echo "-----------------------------------------------------------------------"

KEPTN_DYNATRACE_SERVICE_VERSION="0.10.2"
KEPTN_DYNATRACE_SLI_SERVICE_VERSION="release-0.7.3"
KEPTN_DYNATRACE_MONACO_SERVICE_VERSION="release-0.2.1"

echo "-----------------------------------------------------------------------"
echo "Version Details"
echo "K3S_VERSION=${K3S_VERSION}"
echo "HELM_VERSION=${HELM_VERSION}"
echo "ISTIO_VERSION=${ISTIO_VERSION}"
echo "KEPTN_VERSION=${KEPTN_VERSION}"
echo "-----------------------------------------------------------------------"

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

echo "-----------------------------------------------------------------------"
echo "Install Keptn"
echo "-----------------------------------------------------------------------"
wget https://storage.googleapis.com/keptn-installer/keptn-${KEPTN_VERSION}.tgz
helm upgrade keptn keptn-${KEPTN_VERSION}.tgz --install -n keptn --create-namespace --wait --set=continuous-delivery.enabled=true
rm keptn-${KEPTN_VERSION}.tgz
echo "-----------------------------------------------------------------------"
echo "Waiting for Keptn pods to be ready (max 5 minutes)"
echo "-----------------------------------------------------------------------"
kubectl wait --namespace=keptn --for=condition=Ready pods --timeout=300s --all


PUBLIC_IP=$(curl -s ifconfig.me)
PUBLIC_IP_AS_DOM=$(echo $PUBLIC_IP | sed 's~\.~-~g')
export DOMAIN="${PUBLIC_IP_AS_DOM}.nip.io"
export K8S_DOMAIN="${DOMAIN}"

echo "PUBLIC_IP=${PUBLIC_IP}"
echo "PUBLIC_IP_AS_DOM=${PUBLIC_IP_AS_DOM}"
echo "DOMAIN=${DOMAIN}"
echo "K8S_DOMAIN=${K8S_DOMAIN}"


INGRESS_PORT=${INGRESS_PORT:-80}
INGRESS_PROTOCOL=${INGRESS_PROTOCOL:-http}
ISTIO_GATEWAY=${ISTIO_GATEWAY:-public-gateway.istio-system}

KEPTN_INGRESS_HOSTNAME="keptn.$K8S_DOMAIN"
KEPTN_ENDPOINT="http://$KEPTN_INGRESS_HOSTNAME"

KEPTN_API_TOKEN=$(kubectl get secret keptn-api-token -n keptn -ojsonpath={.data.keptn-api-token} | base64 --decode)
BRIDGE_USERNAME=$(kubectl get secret bridge-credentials -n keptn -o jsonpath={.data.BASIC_AUTH_USERNAME} | base64 -d)
BRIDGE_PASSWORD=$(kubectl get secret bridge-credentials -n keptn -o jsonpath={.data.BASIC_AUTH_PASSWORD} | base64 -d)

GIT_USER=$(kubectl get secret bridge-credentials -n keptn -o jsonpath={.data.BASIC_AUTH_USERNAME} | base64 -d)
GIT_PASSWORD=$(kubectl get secret bridge-credentials -n keptn -o jsonpath={.data.BASIC_AUTH_PASSWORD} | base64 -d)
GIT_SERVER="http://git.$K8S_DOMAIN"


echo "INGRESS_PORT=${INGRESS_PORT}"
echo "INGRESS_PROTOCOL=${INGRESS_PROTOCOL}"
echo "ISTIO_GATEWAY=${ISTIO_GATEWAY}"

echo "KEPTN_INGRESS_HOSTNAME=${KEPTN_INGRESS_HOSTNAME}"
echo "KEPTN_ENDPOINT=${KEPTN_ENDPOINT}"

echo "KEPTN_API_TOKEN=${KEPTN_API_TOKEN}"
echo "BRIDGE_USERNAME=${BRIDGE_USERNAME}"
echo "BRIDGE_PASSWORD=${BRIDGE_PASSWORD}"
echo "GIT_USER=${GIT_USER}"
echo "GIT_PASSWORD=${GIT_PASSWORD}"
echo "GIT_SERVER=${GIT_SERVER}"


echo "-----------------------------------------------------------------------"

echo "-----------------------------------------------------------------------"
echo "Exposes the Keptn Bridge via Istio Ingress: $KEPTN_INGRESS_HOSTNAME"
echo "-----------------------------------------------------------------------"

cat > ./keptn-ingress.yaml <<- EOM
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: istio
  name: api-keptn-ingress
  namespace: keptn
spec:
  rules:
  - host: keptn.$K8S_DOMAIN
    http:
      paths:
      - backend:
          serviceName: api-gateway-nginx
          servicePort: 80
EOM
kubectl apply -f ./keptn-ingress.yaml

cat > ./gateway.yaml <<- EOM
---
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: public-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      name: http
      number: 80
      protocol: HTTP
    hosts:
    - '*'
EOM
kubectl apply -f ./gateway.yaml

echo "-----------------------------------------------------------------------"
echo "Ensure Keptns Helm Service has the correct Istio ingress information: $KEPTN_INGRESS_HOSTNAME"
echo "-----------------------------------------------------------------------"
echo "Create ConfigMap"
kubectl create configmap -n keptn ingress-config --from-literal=ingress_hostname_suffix=${KEPTN_INGRESS_HOSTNAME} --from-literal=ingress_port=${INGRESS_PORT} --from-literal=ingress_protocol=${INGRESS_PROTOCOL} --from-literal=istio_gateway=${ISTIO_GATEWAY} -oyaml --dry-run | kubectl replace -f -
echo "-----------------------------------------------------------------------"
echo "Restart Helm Service"
echo "-----------------------------------------------------------------------"
kubectl delete pod -n keptn --selector=app.kubernetes.io/name=helm-service


echo "-----------------------------------------------------------------------"
echo "Install & Configure Keptn Dynatrace integration"
echo "-----------------------------------------------------------------------"
echo "Create the Dynatrace Secret in the keptn namespace"
kubectl create secret generic -n keptn dynatrace \
    --from-literal="DT_TENANT=$DT_TENANT" \
    --from-literal="DT_API_TOKEN=$DT_API_TOKEN" \
    --from-literal="KEPTN_API_URL=${KEPTN_ENDPOINT}/api" \
    --from-literal="KEPTN_API_TOKEN=${KEPTN_API_TOKEN}" \
    --from-literal="KEPTN_BRIDGE_URL=${KEPTN_ENDPOINT}/bridge" || true

echo "Make Dynatrace the default SLI provider for keptn"
kubectl create configmap lighthouse-config -n keptn --from-literal=sli-provider=dynatrace || true

echo "Install the dynatrace service for keptn"
kubectl apply -n keptn -f https://raw.githubusercontent.com/keptn-contrib/dynatrace-service/${KEPTN_DYNATRACE_SERVICE_VERSION}/deploy/service.yaml

echo "Install the Dynatrace SLI Service for keptn"
kubectl apply -n keptn -f https://raw.githubusercontent.com/keptn-contrib/dynatrace-sli-service/${KEPTN_DYNATRACE_SLI_SERVICE_VERSION}/deploy/service.yaml

echo "Install Dynatrace Monaco Keptn Service"
kubectl apply -n keptn -f https://raw.githubusercontent.com/keptn-sandbox/monaco-service/${KEPTN_DYNATRACE_MONACO_SERVICE_VERSION}/deploy/service.yaml

echo "Authenticate Keptn CLI"
keptn auth  --api-token "${KEPTN_API_TOKEN}" --endpoint "${KEPTN_ENDPOINT}/api"


echo "-----------------------------------------------------------------------"
echo "Clone GitHub Repo
echo "-----------------------------------------------------------------------"
git clone --branch $REPO_RELEASE $REPO $REPO_DIR --single-branch"


defaultProject


defaultProject() {
  if [ "$create_default_project" = true ]; then
    echo "Create Default Dynatrace project"
    keptn create project dynatrace --shipyard=$REPO_DIR/setup/shipyard.yaml
  fi
}


echo "-----------------------------------------------------------------------"
echo "Installing Gitea as Git service for our upstream git repos"
echo "-----------------------------------------------------------------------"
echo "Add gitea-charts to helm"
helm repo add gitea-charts https://dl.gitea.io/charts/

GITEA_DIR = "${REPO_DIR}/setup/gitea"
source $GITEA_DIR/gitea-vars.sh

echo "Create namespace for git"
kubectl create ns git

sed -e 's~domain.placeholder~'"$K8S_DOMAIN"'~' \
    -e 's~GIT_USER.placeholder~'"$GIT_USER"'~' \
    -e 's~GIT_PASSWORD.placeholder~'"$GIT_PASSWORD"'~' \
    $GITEA_DIR/helm-gitea.yaml > $GITEA_DIR/gen/helm-gitea.yaml

echo "Install gitea via Helmchart"
helm install gitea gitea-charts/gitea -f $GITEA_DIR/gen/helm-gitea.yaml --namespace git

echo "Setup Gitea ingress"
cat $GITEA_DIR/gitea-ingress.yaml | sed 's~domain.placeholder~'"$K8S_DOMAIN"'~' > $GITEA_DIR/gen/gitea-ingress.yaml
kubectl apply -f $GITEA_DIR/gen/gitea-ingress.yaml


echo "-----------------------------------------------------------------------"
echo "Waiting for Gitea pods to be ready (max 5 minutes)"
echo "-----------------------------------------------------------------------"
kubectl wait --namespace=git --for=condition=Ready pods --timeout=300s --all

customerProject(){
  if [ "$create_customer_project" = true ]; then
    echo "Create Customer project"

  fi
}


echo "-----------------------------------------------------------------------"
echo "FINISHED SETUP!!"
echo "-----------------------------------------------------------------------"
echo "Keptn "

echo "API URL   :      ${KEPTN_ENDPOINT}/api"
echo "Bridge URL:      ${KEPTN_ENDPOINT}/bridge"
echo "Bridge Username: $BRIDGE_USERNAME"
echo "Bridge Password: $BRIDGE_PASSWORD"
echo "API Token :      $KEPTN_API_TOKEN"

echo "Git Server:      $GIT_SERVER"
echo "Git User:        $GIT_USER"
echo "Git Password:    $GIT_PASSWORD"