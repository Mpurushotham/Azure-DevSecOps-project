#!/usr/bin/env bash
# Minimal script to install ArgoCD into cluster (run in context where kubectl is configured)
set -euo pipefail
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
echo "ArgoCD installed. To access UI, port-forward or use ingress based on your setup."
