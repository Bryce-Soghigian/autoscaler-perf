#!/bin/bash

# This deploys Provisioner requiring small instances (2 vCPU) and 'inflate' deployment with 1 cpu request, requiring VM per replica.
# It then scales the deployment up to the requested number of replicas (allocating the same number of VMs) and then scales it down.
# make az-mon-deploy and az-mon-access will configure some monitoring dashboards that can be used to observe the scale up.


set -euxo pipefail

if [ -z "$1" ]; then echo pass number of replicas; exit 1; fi
replicas="$1"

FMT='+%Y-%m-%dT%H-%M-%SZ'
START=$(date ${FMT})

# Check if the operating system is macOS or Linux
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS, use BSD date syntax
    STARTKUBECTL=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
else
    # Linux, use GNU date syntax
    STARTKUBECTL=$(date --iso-8601=seconds)
fi

mkdir -p logs
exec > >(tee -i "logs/az-perftest-${START}-${replicas}.log")
exec 2>&1
logk="logs/az-perftest-${START}-${replicas}-karpenter.log"

kubectl apply -f https://raw.githubusercontent.com/Azure/karpenter-provider-azure/main/examples/workloads/inflate.yaml

# scale up
date
kubectl scale --replicas="${replicas}" deployment/inflate
time kubectl rollout status deployment/inflate --watch --timeout=2h
date
ENDUP=$(date ${FMT})
echo Scale up: ${START} ${ENDUP} ${replicas} 
