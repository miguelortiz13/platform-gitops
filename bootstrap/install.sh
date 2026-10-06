#!/usr/bin/env bash
set -euo pipefail

echo "==> Creating namespace argocd..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo "==> Adding and updating Argo Helm repository..."
helm repo add argo https://argoproj.github.io/argo-helm || true
helm repo update argo

echo "==> Installing Argo CD via Helm..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --version 10.9.6 \
  --values "${SCRIPT_DIR}/argocd-values.yaml" \
  --wait

echo "==> Applying Root Application for App-of-Apps..."
kubectl apply -f "${SCRIPT_DIR}/root-application.yaml"

echo "==> Argo CD bootstrap complete!"
