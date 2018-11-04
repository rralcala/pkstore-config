# Follow the same order of the target the first time.
# And adjust these:
CLUSTER_NAME=standard-cluster-1
ZONE=us-central1-a
PROJECT=pkstore-221110

ZIPKIN_POD_NAME=$(shell kubectl -n istio-system get pod -l app=zipkin -o jsonpath='{.items[0].metadata.name}')
JAEGER_POD_NAME=$(shell kubectl -n istio-system get pod -l app=jaeger -o jsonpath='{.items[0].metadata.name}')
SERVICEGRAPH_POD_NAME=$(shell kubectl -n istio-system get pod -l app=servicegraph -o jsonpath='{.items[0].metadata.name}')
GRAFANA_POD_NAME=$(shell kubectl -n istio-system get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}')
PROMETHEUS_POD_NAME=$(shell kubectl -n istio-system get pod -l app=prometheus -o jsonpath='{.items[0].metadata.name}')

.PHONY: deploy-istio

grants:
	gcloud container clusters get-credentials $(CLUSTER_NAME)  --zone $(ZONE) --project $(PROJECT)
	kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(shell gcloud config get-value core/account)

deploy-istio:
	curl -L https://git.io/getLatestIstio | sh -
	kubectl apply -f ./$(shell ls -d istio-*)/install/kubernetes/helm/istio/templates/crds.yaml
	kubectl apply -f ./$(shell ls -d istio-*)/install/kubernetes/istio-demo.yaml

deploy:
	kubectl apply -f namespaces.yaml
	kubectl label namespace default istio-injection=enabled
	kubectl apply -f pkstore.yaml
	kubectl apply -f pkstore-service.yaml
	kubectl apply -n storage -f flatdb.yaml
	kubectl apply -n storage -f flatdb-service.yaml
	kubectl apply -f ingress.yaml
	kubectl apply -f destinationrules.yaml
	kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

start-monitoring-services:
	$(shell kubectl -n istio-system port-forward $(JAEGER_POD_NAME) 16686:16686 & kubectl -n istio-system port-forward $(SERVICEGRAPH_POD_NAME) 8088:8088 & kubectl -n istio-system port-forward $(GRAFANA_POD_NAME) 3000:3000 & kubectl -n istio-system port-forward $(PROMETHEUS_POD_NAME) 9090:9090)
