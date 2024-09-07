#!/bin/bash

args=("$@")

export EKSName
if test -f .eks/eks.id; then
    EKSName=$(cat ".eks/eks.id")
fi
echo $EKSName
export KUBECONFIG="$EKSName/$EKSName-eks-a-cluster.kubeconfig"

#EKS
export HELM_EXPERIMENTAL_OCI=1

tail(){
    local log_file="/var/log/cloud-init-output.log"
    SIZE=5
    idx=0

    while read line
    do
        arr[$idx]=$line
        idx=$(( ( idx + 1 ) % SIZE )) 
    done < $log_file

    for ((i=0; i<SIZE; i++))
    do
        echo ${arr[$idx]}
        idx=$(( ( idx + 1 ) % SIZE )) 
    done
}

update(){
    helm --kubeconfig $KUBECONFIG repo update
    helm --kubeconfig $KUBECONFIG repo list
}

delete(){
    NAME="${args[1]}"
    helm --kubeconfig $KUBECONFIG del --purge ${NAME}
    kubectl --kubeconfig $KUBECONFIG delete --namespace ${NAME} --all pvc
}

ls(){
    kubectl --kubeconfig=$KUBECONFIG get pods --all-namespaces   
}

dashboard(){
    token
    kubectl --kubeconfig=$KUBECONFIG -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443 --address 0.0.0.0
}

cms(){
    CMS="${args[1]}"
    kubectl --kubeconfig=$KUBECONFIG port-forward -n solodev service/${CMS}-ui 80:8080 --address 0.0.0.0
}

#SETUP
clean(){
    NAME="${args[1]}"
    kubectl --kubeconfig $KUBECONFIG delete --all daemonsets,replicasets,statefulsets,services,ingress,deployments,pods,rc,configmap --namespace=${NAME} --grace-period=0 --force
    kubectl --kubeconfig $KUBECONFIG delete --namespace ${NAME} --all pvc,pv
}

token(){
    kubectl --kubeconfig=$KUBECONFIG -n kube-system create token solodev-admin
}

install(){
    #APP
    if [[ ${args[1]} ]]; then APP="${args[1]}"
    else 
        echo -n "What app do you want to install?"
        read APP
    fi

    if [[ "$APP" == "dashboard" ]]; then
        installdashboard
    elif [[ "$APP" == "cms" ]]; then
        #NAMESPACE
        if [[ ${args[2]} ]]; then NAMESPACE="${args[2]}"
        else 
            echo -n "What namespace do you want to use?"
            read NAMESPACE
        fi

        #RELEASE
        if [[ ${args[3]} ]]; then RELEASE="${args[3]}"
        else 
            echo -n "What release do you want to use?"
            read RELEASE
        fi
        installcms $NAMESPACE $RELEASE
    else
        echo "Error: ${APP} undefined"
    fi
}

upgrade(){
    #APP
    if [[ ${args[1]} ]]; then APP="${args[1]}"
    else 
        echo -n "What app do you want to upgrade?"
        read APP
    fi

    #NAME
    if [[ ${args[2]} ]]; then NAME="${args[2]}"
    else 
        echo -n "What is the deployment name?"
        read NAME
    fi

    #RELEASE
    if [[ ${args[3]} ]]; then RELEASE="${args[3]}"
    else 
        echo -n "What release do you want to upgrade to?"
        read RELEASE
    fi

    if [[ "$APP" == "dashboard" ]]; then
        echo "Not available at this time"
    elif [[ "$APP" == "cms" ]]; then
        upgradecms $NAME $RELEASE
    else
        echo "Error: ${APP} undefined"
    fi
}

installdashboard(){
    helm --kubeconfig $KUBECONFIG repo update
    helm --kubeconfig $KUBECONFIG repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
    helm --kubeconfig $KUBECONFIG upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard
}

installcms(){
    DEFAULT_NAMESPACE="solodev"
    NAMESPACE=${args[1]:-$DEFAULT_NAMESPACE}
    DEFAULT_RELEASE="latest"
    RELEASE=${args[2]:-$DEFAULT_RELEASE}
    NAME=cms$(date +"%Y%m%d%S")

    #AWS License Check
    licensecms $NAMESPACE

    aws ecr get-login-password \
        --region us-east-1 | helm --kubeconfig $KUBECONFIG registry login \
        --username AWS \
        --password-stdin 709825985650.dkr.ecr.us-east-1.amazonaws.com

    if [[ "$RELEASE" == "latest" ]]; then
        aws s3 cp s3://solodev-release/version.txt version.txt
        RELEASE=$(cat version.txt)
    fi

    helm --kubeconfig $KUBECONFIG install cms$(date +"%Y%m%d%S") oci://709825985650.dkr.ecr.us-east-1.amazonaws.com/solodev/solodev-cms-aws \
        --version $RELEASE --namespace $NAMESPACE --set serviceAccount.create=false --set serviceAccount.name=solodev-service-account --set aws.mpLicenseSecretName=cms-license-token-secret --set storage.className=openebs-hostpath
}

licensecms(){
    NAMESPACE="$1"
    accountID=$(aws sts get-caller-identity --query 'Account' --output text) 
    AWSMP_ROLE_ARN=arn:aws:iam::${accountID}:role/service-role/AWSMarketplaceLicenseTokenConsumptionRole

    if test -f .eks/cmslicense; then
        AWSMP_TOKEN=$(cat .eks/cmslicense)
    else
        if [[ $2 ]]; then AWSMP_TOKEN="$2"
        else 
            echo -n "What is the token value from AWS Marketplace?"
            read AWSMP_TOKEN
        fi
    fi

    #The total number of GetAccessToken calls that can be made for a license per hour = 10
    AWSMP_ACCESS_TOKEN=$(aws license-manager get-access-token --output text --query '*' --token $AWSMP_TOKEN --region us-east-1)
    AWSMP_ROLE_CREDENTIALS=$(aws sts assume-role-with-web-identity \
        --region 'us-east-1' \
        --role-arn $AWSMP_ROLE_ARN \
        --role-session-name 'eksa-deployment-session' \
        --web-identity-token $AWSMP_ACCESS_TOKEN \
        --query 'Credentials' \
        --output text)   
                
    export AWS_ACCESS_KEY_ID=$(echo $AWSMP_ROLE_CREDENTIALS | awk '{print $1}' | xargs)
    export AWS_SECRET_ACCESS_KEY=$(echo $AWSMP_ROLE_CREDENTIALS | awk '{print $3}' | xargs)
    export AWS_SESSION_TOKEN=$(echo $AWSMP_ROLE_CREDENTIALS | awk '{print $4}' | xargs)

    kubectl --kubeconfig=$KUBECONFIG delete secret awsmp-image-pull-secret --namespace $NAMESPACE --ignore-not-found
    kubectl --kubeconfig=$KUBECONFIG create secret docker-registry awsmp-image-pull-secret \
        --docker-server=709825985650.dkr.ecr.us-east-1.amazonaws.com \
        --docker-username=AWS \
        --docker-password=$(aws ecr get-login-password --region us-east-1) \
        --namespace $NAMESPACE

    if ! test -f .eks/cmslicense; then
        #Run Setup
        kubectl --kubeconfig=$KUBECONFIG delete serviceaccount solodev-service-account --namespace $NAMESPACE --ignore-not-found
        kubectl --kubeconfig=$KUBECONFIG create serviceaccount solodev-service-account --namespace $NAMESPACE

        kubectl --kubeconfig=$KUBECONFIG delete secret cms-license-token-secret --namespace $NAMESPACE --ignore-not-found
        kubectl --kubeconfig=$KUBECONFIG create secret generic cms-license-token-secret \
            --from-literal=license_token=$AWSMP_TOKEN \
            --from-literal=iam_role=$AWSMP_ROLE_ARN \
            --namespace $NAMESPACE

        kubectl --kubeconfig=$KUBECONFIG patch serviceaccount solodev-service-account \
            --namespace $NAMESPACE \
            -p '{"imagePullSecrets": [{"name": "awsmp-image-pull-secret"}]}'

        #Register token
        echo $AWSMP_TOKEN > .eks/cmslicense
    fi
}

upgradecms(){
    NAME="${args[2]}"
    RELEASE="${args[3]}"
    aws ecr get-login-password \
        --region us-east-1 | helm --kubeconfig $KUBECONFIG registry login \
        --username AWS \
        --password-stdin 709825985650.dkr.ecr.us-east-1.amazonaws.com

    helm --kubeconfig $KUBECONFIG upgrade $NAME oci://709825985650.dkr.ecr.us-east-1.amazonaws.com/solodev/solodev-cms-aws \
        --version $RELEASE --namespace solodev
}

$*