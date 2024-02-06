# Cluster Autoscaler of 10 years in development, or AKS Karpenter of 10 months into development, which reigns supreme?
This document serves as a measurement of cluster autoscaler vs karpenter performance of the preview karpenter product.

## Benchmarks 
What will be attempting 
1. Time to 500 nodes 
2. Time to schedule 1000 pods
3. Price for scale up and down in the pattern of 10, 50, 100, 250, 100, 50, 10 pods. 


We will track these things via prometheus
The Clusters we will create will be: 
karpenter-arm-spot
karpenter-custom-batch 
cas-default 
cas-cost-optimized-bin-packed
cas-bursty
Each representing a different optimization goal


The Base Cluster Configuration we will use is the following
```
az aks create -g cas-clusters -n $clusterName \
--node-count 10 \
--enable-addons monitoring \
--generate-ssh-keys \
--tier standard \
--network-plugin azure --network-plugin-mode overlay --network-dataplane cilium 
```
WE will use Cilium and Azure, alongside a paid tier apiserver via the aks standard tier



### Cluster Autoscaler Profiles 
1. Default Autoscaler: Using the standard defaults aks sets 
Setting	Description	Default value
scan-interval	How often the cluster is reevaluated for scale up or down.	10 seconds
scale-down-delay-after-add	How long after scale up that scale down evaluation resumes.	10 minutes
scale-down-delay-after-delete	How long after node deletion that scale down evaluation resumes.	scan-interval
scale-down-delay-after-failure	How long after scale down failure that scale down evaluation resumes.	Three minutes
scale-down-unneeded-time	How long a node should be unneeded before it's eligible for scale down.	10 minutes
scale-down-unready-time	How long an unready node should be unneeded before it's eligible for scale down.	20 minutes
ignore-daemonsets-utilization (Preview)	Whether DaemonSet pods will be ignored when calculating resource utilization for scale down.	false
daemonset-eviction-for-empty-nodes (Preview)	Whether DaemonSet pods will be gracefully terminated from empty nodes.	false
daemonset-eviction-for-occupied-nodes (Preview)	Whether DaemonSet pods will be gracefully terminated from non-empty nodes.	true
scale-down-utilization-threshold	Node utilization level, defined as sum of requested resources divided by capacity, in which a node can be considered for scale down.	0.5
max-graceful-termination-sec	Maximum number of seconds the cluster autoscaler waits for pod termination when trying to scale down a node.	600 seconds
balance-similar-node-groups	Detects similar node pools and balances the number of nodes between them.	false
expander	Type of node pool expander uses in scale up. Possible values include most-pods, random, least-waste, and priority.	
skip-nodes-with-local-storage	If true, cluster autoscaler doesn't delete nodes with pods with local storage, for example, EmptyDir or HostPath.	true
skip-nodes-with-system-pods	If true, cluster autoscaler doesn't delete nodes with pods from kube-system (except for DaemonSet or mirror pods).	true
max-empty-bulk-delete	Maximum number of empty nodes that can be deleted at the same time.	10 nodes
new-pod-scale-up-delay	For scenarios such as burst/batch scale where you don't want CA to act before the Kubernetes scheduler could schedule all the pods, you can tell CA to ignore unscheduled pods before they reach a certain age.	0 seconds
max-total-unready-percentage	Maximum percentage of unready nodes in the cluster. After this percentage is exceeded, CA halts operations.	45%
max-node-provision-time	Maximum time the autoscaler waits for a node to be provisioned.	15 minutes
ok-total-unready-count	Number of allowed unready nodes, irrespective of max-total-unready-percentage.	Three nodes
2. Cost Optimized Scale Down Profile 
scan-interval: 30s 
scale-down-delay-after-add: 0s 
scale-down-delay-after-delete: 0s 
scale-down-delay-after-failure: 0s 
scale-down-unneeded-time: 3m 
scale-down-unready-time: 3m 
daemonset-eviction-for-empty-nodes: false 
daemonset-eviction-for-occupied-nodes 
max-graceful-termination-sec: 30s 
skip-nodes-with-local-storage: false 
max-empty-bulk-delete: 1000 
max-total-unready-percentage: 100 
ok-total-unready-count: 1000 
max-node-provision-time: 30m

This is the best we can do with the flags we have exposed today. If we were to use all of the flags in the autoscaler we could save some money on perf but oh well.

3. Bursty Profile
TODO: 


#### Nodepool Configuration 
To give cluster autoscaler a fighting chance, we should give it nodepools with 2, 4, 8, 16, 32, 64, 96 VCPUs so that cluster autoscaler can bin pack properly

### Karpenter Configuration 
For Time to schedule 1000 pods, we will give karpenter its default nap settings. As for Time to 500 nodes, we will have to artificially limit the size of the nodepool to be for small nodes. We can use the karpenter perf scripts present in the aks karpenter provider repo

For the Large node run we will set the batch interval to 30 seconds to have parity with Cluster Autoscaler's ideal configuration. Note we will just be running with sta
