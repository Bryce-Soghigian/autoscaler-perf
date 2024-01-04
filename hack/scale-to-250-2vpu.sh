#!/bin/bash

NAMESPACE="default" 
DEPLOYMENT_NAME="inflate" 
TARGET_REPLICAS=250
POD_MILESTONES=(25 50 75 100)
NODE_MILESTONES=(10 50 100 200 250)
LOG_FILE="scaling_report_$(date +%Y%m%d_%H%M%S).txt"

echo "Scaling Report - Start Time: $(date)" | tee -a "$LOG_FILE"

scale_deployment() {
    kubectl scale deployment/$DEPLOYMENT_NAME --replicas=$1 -n $NAMESPACE
}

monitor_scaling() {
    local pods_scheduled=0
    local nodes_count=0
    local start_time=$(date +%s)

    while true; do
        pods_scheduled=$(kubectl get pods -n $NAMESPACE -o=jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | wc -w)
        
        nodes_count=$(kubectl get nodes -o=jsonpath='{.items[*].metadata.name}' | wc -w)

        for milestone in "${POD_MILESTONES[@]}"; do
            if (( pods_scheduled >= milestone * TARGET_REPLICAS / 100 )); then
                echo "Time to schedule $milestone% pods: $(($(date +%s) - start_time)) seconds" | tee -a "$LOG_FILE"
                POD_MILESTONES=(${POD_MILESTONES[@]/$milestone})
                break
            fi
        done

        for milestone in "${NODE_MILESTONES[@]}"; do
            if (( nodes_count >= milestone )); then
                echo "Time to scale to $milestone nodes: $(($(date +%s) - start_time)) seconds" | tee -a "$LOG_FILE"
                NODE_MILESTONES=(${NODE_MILESTONES[@]/$milestone})
                break
            fi
        done

        if [[ ${#POD_MILESTONES[@]} -eq 0 && ${#NODE_MILESTONES[@]} -eq 0 ]]; then
            break
        fi

        sleep 10
    done
}

scale_deployment $TARGET_REPLICAS

monitor_scaling

echo "Scaling Report - End Time: $(date)" | tee -a "$LOG_FILE"

