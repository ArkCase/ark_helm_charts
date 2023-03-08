# install eksctl client version 1.21

# Create the cluster

./create_cluster.sh

eksctl create cluster \
--name alfresco-eks \
--version 1.21 \
--region us-east-1 \
--zones us-east-1a,us-east-1b \
--nodegroup-name alfresco-linux-nodes \
--nodes 2 \
--node-type m5.xlarge \
--nodes-min 0 \
--nodes-max 2 \
--with-oidc \
--ssh-access \
--ssh-public-key "~/.ssh/armcsbs-public.pub" \
--managed

# set the region and profile

AWS_PROFILE=ark-cli
AWS_REGION=ap-south-1

# add the aws sso profile

cat ~/.aws/config
[profile ark-cli]
sso_start_url = https://xxx-umbrella.awsapps.com/start
sso_region = us-east-1
sso_account_id = xxxx
sso_role_name = AdministratorAccess
region = ap-south-1
output = json

# update local kubeconfig for LENS IDE

aws eks --region us-east-1 update-kubeconfig --name alfresco-eks

aws eks --region ap-south-1 update-kubeconfig --name arkcase-eks

# Make sure to use correct cluster

kubectl config use-context  arn:aws:eks:us-east-1:300674751221:cluster/alfresco-eks

kubectl config use-context  arn:aws:eks:ap-south-1:345280441424:cluster/arkcase-eks

# download istio

curl -L https://github.com/istio/istio/releases/download/1.10.3/istio-1.10.3-win.zip  --output istio-1.10.3-win.zip

# Install istio using demo profile

## This will install the Istio 1.10.3 demo profile with ["Istio core" "Istiod" "Ingress gateways" "Egress gateways"] components into the cluster

## and creates the AWS classic ELB

istioctl install --set profile=demo

helm repo update

# create EFS and ensure a mount target is created in each public subnet (since not using private nodes)

./create-efs.sh

# create alfresco namespace and add label for istio injection

kubectl create namespace alfresco

kubectl label namespace alfresco istio-injection=enabled

kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

result:  a057bcf2e007f4be2baf6e85570cd540-1695087874.us-east-1.elb.amazonaws.com
result (india): a33a9f10544dd481a9ceba4fac1d7156-1392466058.ap-south-1.elb.amazonaws.com

# copied the alfresco helm chart repo locally to disable t-engines, search services in values.yaml and added enabled flag to each deployment template

For example:  {{- if .Values.tika.enabled }}

# download the dependancy charts like postgress

helm dependency update ./alfresco-content-services/

# validate helm chart

helm lint .

helm install --dry-run --generate-name . --values=community_values.yaml --set externalPort="80" --set externalProtocol="http" --set externalHost="a057bcf2e007f4be2baf6e85570cd540-1695087874.us-east-1.elb.amazonaws.com" --set persistence.enabled=true --set persistence.storageClass.enabled=true --set persistence.storageClass.name="nfs-client"

# install the helm chart after validation passes

helm upgrade --install acs . \
--values=community_values.yaml \
--set externalPort="80" \
--set externalProtocol="http" \
--set externalHost="a33a9f10544dd481a9ceba4fac1d7156-1392466058.ap-south-1.elb.amazonaws.com" \
--set persistence.enabled=true \
--set persistence.storageClass.enabled=true \
--set persistence.storageClass.name="nfs-client" \
--atomic \
--timeout 10m0s \
--namespace=arkcase

# to get access to the /alfresco and /share end points install the istio gateway virtual services

kubectl -n alfresco apply -f alfresco-istio-gateway.yaml

# secure ingress gateway using a cert

kubectl -n istio-system patch service istio-ingressgateway --patch "$(cat ingress-secure-gateway-patch.yaml)"

# get some ingress stats

kubectl get svc alfresco-istio-gateway -n alfresco

kubectl get gateway -n alfresco

kubectl get vs -n alfresco

istioctl analyze -n alfresco

# Install all istio addons for istio metrics and tracing:
kubectl apply -f samples/addons   (run it twice if any error occurs)

# There are three istio mTLS modes you can use: STRICT , PERMISSIVE and DISABLE

kubectl apply -n alfresco -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: "default"
spec:
  mtls:
    mode: STRICT
EOF

kubectl apply -n alfresco -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: "default"
spec:
  mtls:
    mode: DISABLE
EOF

##################################
# CLEAN UP
##################################

## Reduce nodes to temporarily save costs

eksctl scale nodegroup --cluster alfresco-eks --name alfresco-linux-nodes --nodes 0

## delete the istio addons

kubectl delete -n istio-system -f samples/addons

## delete the istio gateway

kubectl delete -n alfresco -f alfresco-istio-gateway.yaml

## delete the alfresco namespace

kubectl delete namespace alfresco

## should delete the istio ingress ELB in AWS

istioctl x uninstall --purge

kubectl delete namespace istio-system

## Go to the EFS Console, select the file system we created earlier and press the "Delete" button to remove the mount targets and file system.

eksctl delete cluster --name alfresco-eks
