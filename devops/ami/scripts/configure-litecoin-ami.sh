tee /root/init-eksa.sh <<'EOF'
#!/bin/bash
EC2_INSTANCE_ID="`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id || die \"wget instance-id has failed: $?\"`"
test -n "$EC2_INSTANCE_ID" || die 'cannot obtain instance-id'
EC2_AVAIL_ZONE="`wget -q -O - http://169.254.169.254/latest/meta-data/placement/availability-zone || die \"wget availability-zone has failed: $?\"`"
test -n "$EC2_AVAIL_ZONE" || die 'cannot obtain availability-zone'
EC2_REGION="\`echo "$EC2_AVAIL_ZONE" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'\`"

echo "Create Cluster"
export pwd="/root"
cd $pwd

mkdir -p /root/.eksa
chmod 700 /root/eksa

echo $EC2_INSTANCE_ID > .eks/eks.id

export EKSName=$EC2_INSTANCE_ID
export KUBECONFIG="$EKSName/$EKSName-eks-a-cluster.kubeconfig"

eksctl anywhere generate clusterconfig $EKSName --provider docker > $EKSName.yaml

#Disable External ETCD
yq -i 'del(.spec.externalEtcdConfiguration)' $EKSName.yaml

eksctl anywhere create cluster -f $EKSName.yaml -v 6
    #FOR AIRGAP
    # eksctl anywhere import images -i images.tar -r localhost:5000 --bundles ./eks-anywhere-downloads/bundle-release.yaml --insecure
    # eksctl anywhere create cluster -f $EKSName.yaml --bundles-override ./eks-anywhere-downloads/bundle-release.yaml

eksctl register cluster --name $EKSName --provider EKS_ANYWHERE --region us-east-1 -v 6

kubectl --kubeconfig=$KUBECONFIG apply -f eks-connector.yaml,eks-connector-clusterrole.yaml,eks-connector-console-dashboard-full-access-group.yaml

#Permission to view Kubernetes resources of connected cluster from AWS Console
curl -o eks-connector-console-dashboard-full-access-group.yaml https://s3.us-west-2.amazonaws.com/amazon-eks/eks-connector/manifests/eks-connector-console-roles/eks-connector-console-dashboard-full-access-group.yaml
kubectl --kubeconfig=$KUBECONFIG apply -f eks-connector-console-dashboard-full-access.yaml

#Granting access to IAM user or Role to view Kubernetes resources in Amazon EKS console
curl -o eks-connector-clusterrole.yaml https://s3.us-west-2.amazonaws.com/amazon-eks/eks-connector/manifests/eks-connector-console-roles/eks-connector-clusterrole.yaml
kubectl --kubeconfig=$KUBECONFIG apply -f eks-connector-clusterrole.yaml

#Solodev Admin Role and namespace
kubectl --kubeconfig=$KUBECONFIG create namespace solodev
kubectl --kubeconfig=$KUBECONFIG apply -f solodev-admin-service-account.yaml

#Check for Package Controller
kubectl --kubeconfig=$KUBECONFIG get pods -n eksa-packages | grep "eks-anywhere-packages"

# eksctl anywhere copy packages \
#   localhost:5000/curated-packages \
#   --kube-version 1.29 \
#   --src-chart-registry public.ecr.aws/eks-anywhere \
#   --src-image-registry 783794618700.dkr.ecr.us-west-2.amazonaws.com

#Install OpenEBS
helm --kubeconfig $KUBECONFIG repo add openebs https://openebs.github.io/openebs
helm --kubeconfig $KUBECONFIG repo update
helm --kubeconfig $KUBECONFIG install openebs --namespace openebs openebs/openebs --set engines.replicated.mayastor.enabled=false --create-namespace

#Delete all setup yamls
rm -f *.yaml

#End
kubectl --kubeconfig=$KUBECONFIG get ns
echo "kubectl --kubeconfig=$KUBECONFIG get ns"

rm -f /root/init-eksa.sh
EOF

chmod 700 /root/init-eksa.sh
tee /etc/cloud/cloud.cfg.d/install.cfg <<'EOF'
#install-config
runcmd:
- /root/init-eksa.sh
EOF