#! /usr/bin/env bash

set -e

# Helpers for readability.
bold=$(tput bold)
normal=$(tput sgr0)
function _info() {
    echo "${bold}${1}${normal}"
}

# Run script from directory where the script is stored.
cd "$( dirname "${BASH_SOURCE[0]}" )"

# Create a local Kubernetes cluster.
_info "🔧 Creating a local Kubernetes cluster..."
kind create cluster --name=padok-demo --config=../kind-cluster.yaml

# Install the NGINX ingress controller.
# _info "📥 Installing an ingress controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
kubectl rollout status deployment --namespace=ingress-nginx ingress-nginx-controller
kubectl delete validatingwebhookconfiguration ingress-nginx-admission # Workaround for this issue: https://github.com/kubernetes/ingress-nginx/issues/5401

# Deploy Prometheus.
_info "👀 Deploying Prometheus..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install --wait --namespace=monitoring --create-namespace prometheus prometheus-community/kube-prometheus-stack --values=../helm/values/prometheus.yaml --version=31.0.0

# Install Isito
_info "📥 Installing istio..."
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
helm upgrade --install istio-base istio/base --namespace=istio-system --create-namespace --version=1.12.2
helm upgrade --install istiod istio/istiod --namespace=istio-system --wait --version=1.12.2
helm upgrade --install istio-ingressgateway istio/gateway --namespace=istio-system --create-namespace --values=../helm/values/istio-ingress.yaml --version=1.12.2
kubectl apply -f ../bootstrap-manifests/istio-system/

# Install Kiali
_info "📥 Installing kiali..."
helm repo add kiali https://kiali.org/helm-charts
helm repo update
helm upgrade --install --wait --namespace=istio-system --create-namespace kiali-server kiali/kiali-server --values=../helm/values/kiali.yaml --version=1.45.0

# Install GCP microservices demo
_info "📥 Deploying demo microservices..."
kubectl label namespace default istio-injection=enabled
kubectl apply -f ../bootstrap-manifests/default/

_info "🚀 You are ready to go!"
