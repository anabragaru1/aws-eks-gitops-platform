#!/usr/bin/env bash
# Renders every chart for every environment and validates it against the Kubernetes and CRD schemas.
set -euo pipefail

cd "$(dirname "$0")/.."

K8S_VERSION="${K8S_VERSION:-1.34.0}"
CRD_SCHEMAS='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

validate() {
  # ClusterSecretStore's published schema is not loadable by kubeconform; it is exercised on kind instead.
  kubeconform -strict -summary -kubernetes-version "$K8S_VERSION" \
    -schema-location default -schema-location "$CRD_SCHEMAS" \
    -skip ClusterSecretStore
}

echo "== argocd-bootstrap"
helm template bootstrap terraform/modules/argocd/charts/argocd-bootstrap --set values.environment=dev | validate

echo "== root (dev defaults)"
helm template root kubernetes/argocd/root | validate

echo "== root (prod)"
helm template root kubernetes/argocd/root --set environment=prod | validate

echo "== external-secrets stores"
helm template stores kubernetes/platform/external-secrets/stores | validate

for env in dev prod; do
  echo "== karpenter nodepools ($env)"
  helm template nodepools kubernetes/platform/karpenter/nodepools \
    -f "kubernetes/platform/karpenter/nodepools/values-$env.yaml" | validate
done

for env in dev prod; do
  echo "== api ($env)"
  helm template api kubernetes/apps/api -f "kubernetes/apps/api/values-$env.yaml" \
    --set database.secretArn=arn:aws:secretsmanager:eu-west-1:123456789012:secret:placeholder \
    --set ingress.certificateArn=arn:aws:acm:eu-west-1:123456789012:certificate/placeholder | validate
done
