az login
az account set --subscription $LG_SUB
az group create -n cas-clusters -l eastus

# Cluster Name 
clusterName="cost-optimized-binpacked-7sku"
resourceGroup="cas-clusters2"


# we need more ips for large clusters, 
# A /13 block uses 13 bits for the network, leaving 19 bits for host addresses, yielding 2^(32-13) = 524,288 addresses. 14 or 16 may have been sufficent for this experiment
az network vnet create \
    --name $clusterName \
    --resource-group $resourceGroup \
    --location eastus \
    --address-prefix 10.0.0.0/13

az network vnet subnet create \
    --name mySubnet \
    --resource-group $resourceGroup \
    --vnet-name $clusterName \
    --address-prefix 10.0.0.0/13


az aks create -g myResourceGroup -n $clusterName \
--node-count 10 \
--enable-addons monitoring \
--generate-ssh-keys \
--tier standard \
--cluster-autoscaler-profile scan-interval=30s \
--cluster-autoscaler-profile scale-down-delay-after-add=0s \
--cluster-autoscaler-profile scale-down-delay-after-delete=0s \
--cluster-autoscaler-profile scale-down-delay-after-failure=0s \
--cluster-autoscaler-profile scale-down-unneeded-time=3m \
--cluster-autoscaler-profile scale-down-unready-time=3m \
--cluster-autoscaler-profile max-graceful-termination-sec=30s \
--cluster-autoscaler-profile skip-nodes-with-local-storage=false \
--cluster-autoscaler-profile max-empty-bulk-delete=1000 \
--cluster-autoscaler-profile max-total-unready-percentage=100 \
--cluster-autoscaler-profile ok-total-unready-count=1000 \
--cluster-autoscaler-profile max-node-provision-time=30m \
--network-plugin azure --network-plugin-mode overlay --network-dataplane cilium \
--vnet-subnet-id /subscriptions/$LG_SUB/resourceGroups/$resourceGroup/providers/Microsoft.Network/virtualNetworks/$clusterName/subnets/mySubnet 

az aks get-credentials -g cas-clusters -n $clusterName 

poolNames=("np2" "np4" "np8" "np16" "np32" "np64" "np96")
vmSizes=("Standard_D2s_v3" "Standard_D4s_v3" "Standard_D8s_v3" "Standard_D16s_v3" "Standard_D32s_v3" "Standard_D64s_v3" "Standard_D96s_v3")

# Get the length of the arrays
arrayLength=${#poolNames[@]}

# Loop through the arrays
for (( i=0; i<${arrayLength}; i++ ));
do
    poolName=${poolNames[$i]}
    vmSize=${vmSizes[$i]}
    echo "Creating node pool $poolName with VM size $vmSize"

    # Create the node pool
    az aks nodepool add \
        -g $resourceGroup  \
        -n $poolName \
        --cluster-name $clusterName \
        --node-count 1 \
        --node-vm-size $vmSize \
        --enable-cluster-autoscaler \
        --min-count 0 \
        --max-count 120 
done
