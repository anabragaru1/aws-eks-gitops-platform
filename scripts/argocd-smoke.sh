#!/usr/bin/env bash
# Installs Argo CD on the current cluster, applies the bootstrap chart against this
# repository revision and fails if any Application cannot be rendered by Argo CD.
set -euo pipefail

cd "$(dirname "$0")/.."

: "${REPO_URL:?set REPO_URL}"
: "${TARGET_REVISION:?set TARGET_REVISION}"
REPO_TOKEN="${REPO_TOKEN:-}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-10.10.3}"
TIMEOUT="${TIMEOUT:-600}"

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo update argo >/dev/null

repo_values=""
if [ -n "$REPO_TOKEN" ]; then
  repo_values="--set configs.repositories.platform.url=$REPO_URL --set configs.repositories.platform.username=x-access-token --set configs.repositories.platform.password=$REPO_TOKEN"
fi

echo "== installing Argo CD $ARGOCD_CHART_VERSION"
# shellcheck disable=SC2086
helm upgrade --install argocd argo/argo-cd --version "$ARGOCD_CHART_VERSION" \
  --namespace argocd --create-namespace --wait --timeout 10m \
  --set dex.enabled=false --set notifications.enabled=false \
  --set configs.params."server\.insecure"=true \
  --set configs.cm."timeout\.reconciliation"=30s \
  --set configs.repositories.karpenter.name=karpenter \
  --set configs.repositories.karpenter.url=public.ecr.aws/karpenter \
  --set configs.repositories.karpenter.type=helm \
  --set-string configs.repositories.karpenter.enableOCI=true \
  $repo_values

echo "== applying bootstrap chart"
helm upgrade --install argocd-bootstrap terraform/modules/argocd/charts/argocd-bootstrap \
  --namespace argocd --wait \
  --set repoURL="$REPO_URL" --set targetRevision="$TARGET_REVISION" \
  --set values.source.repoURL="$REPO_URL" --set values.source.targetRevision="$TARGET_REVISION" \
  --set values.environment=dev

expected="root karpenter karpenter-nodepools aws-load-balancer-controller external-dns external-secrets external-secrets-stores api"

echo "== waiting for Applications to be evaluated"
deadline=$((SECONDS + TIMEOUT))
while :; do
  pending=""
  for app in $expected; do
    # Unknown means Argo CD could not evaluate the app yet (or at all); the conditions say why.
    status=$(kubectl -n argocd get application "$app" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)
    case "$status" in ""|Unknown) pending="$pending $app" ;; esac
  done
  [ -z "$pending" ] && break
  if [ $SECONDS -ge $deadline ]; then
    echo "timed out waiting for:$pending"
    kubectl -n argocd get applications -o wide || true
    kubectl -n argocd get applications -o jsonpath='{range .items[*]}{.metadata.name}: {range .status.conditions[*]}{.type}: {.message}{"\n"}{end}{end}' || true
    exit 1
  fi
  sleep 10
done

kubectl -n argocd get applications -o wide

echo "== checking for rendering errors"
failed=0
for app in $expected; do
  errors=$(kubectl -n argocd get application "$app" -o jsonpath='{range .status.conditions[*]}{.type}: {.message}{"\n"}{end}' | grep -E '^[A-Za-z]+Error:' || true)
  if [ -n "$errors" ]; then
    echo "::error::$app: $errors"
    failed=1
  fi
done

echo "== external-secrets CRDs accept the ClusterSecretStore"
kubectl wait --for=condition=Established crd/clustersecretstores.external-secrets.io --timeout=300s
kubectl -n external-secrets rollout status deploy/external-secrets-webhook --timeout=300s
helm template stores kubernetes/platform/external-secrets/stores | kubectl apply --dry-run=server -f -

echo "== karpenter CRDs accept the NodePool and EC2NodeClass"
kubectl wait --for=condition=Established crd/nodepools.karpenter.sh crd/ec2nodeclasses.karpenter.k8s.aws --timeout=300s
for env in dev prod; do
  helm template nodepools kubernetes/platform/karpenter/nodepools \
    -f "kubernetes/platform/karpenter/nodepools/values-$env.yaml" | kubectl apply --dry-run=server -f -
done

exit $failed
