#!/usr/bin/env bash
# One-time setup per cluster:
#   1. install ArgoCD
#   2. create the "root" Application that deploys everything in gitops/apps
# After this, all changes go through Git. Safe to run again (it upgrades ArgoCD).
#
# usage: scripts/bootstrap-argocd.sh <dev|prod>
# needs: aws, terraform, helm, kubectl, jq (and AWS credentials that can reach the cluster)
set -euo pipefail

ENV="${1:?usage: $0 <dev|prod>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-10.15.0}"

# Facts about the cluster (name, region, VPC, RDS endpoint, ...) straight from Terraform.
FACTS="$(terraform -chdir="$ROOT/terraform/envs/$ENV" output -json cluster_facts)"
CLUSTER_NAME="$(jq -r .cluster_name <<<"$FACTS")"
REGION="$(jq -r .aws_region <<<"$FACTS")"
REPO_URL="$(awk '/^repoURL:/ {print $2}' "$ROOT/gitops/apps/values.yaml")"
BRANCH="$(awk '/^branch:/ {print $2}' "$ROOT/gitops/apps/values.yaml")"
VALUES="$(jq -c '{cluster: .}' <<<"$FACTS")"

echo ">> connecting kubectl to $CLUSTER_NAME"
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" >/dev/null

echo ">> installing ArgoCD (chart $ARGOCD_CHART_VERSION)"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo update argo >/dev/null
helm upgrade --install argocd argo/argo-cd \
  --version "$ARGOCD_CHART_VERSION" --namespace argocd --create-namespace \
  -f "$ROOT/gitops/bootstrap/argocd-values.yaml" --wait --timeout 10m

echo ">> creating the root Application ($REPO_URL, $BRANCH, env=$ENV)"
kubectl apply -f - <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
  finalizers: [resources-finalizer.argocd.argoproj.io]
spec:
  project: default
  source:
    repoURL: $REPO_URL
    targetRevision: $BRANCH
    path: gitops/apps
    helm:
      valueFiles: [values.yaml, values-$ENV.yaml]
      valuesObject: $VALUES
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated: {prune: true, selfHeal: true}
YAML

cat <<MSG

Done. Watch it converge:  kubectl -n argocd get applications -w
ArgoCD password:          kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
ArgoCD UI:                kubectl -n argocd port-forward svc/argocd-server 8080:443   ->  https://localhost:8080
MSG
