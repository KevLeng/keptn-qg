#!/bin/bash

K8S_DOMAIN=${K8S_DOMAIN:-none}

if [[ "$K8S_DOMAIN" == "none" ]]; then
    echo "No Domain has been passed, you have to specify a domain."
    echo "Usage: $0 <k8s-domain>"
    exit 1
else 
    echo "Domain has been passed: $K8S_DOMAIN"  
fi

#Default values
GIT_USER=${GIT_USER:-"keptn"}
GIT_PASSWORD=${GIT_PASSWORD:-"keptn#R0cks"}
GIT_SERVER="http://git.$K8S_DOMAIN"

# static vars
GIT_TOKEN="keptn-upstream-token"
TOKEN_FILE=$GIT_TOKEN.json