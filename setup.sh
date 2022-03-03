#!/bin/bash
# This script will run an ARM template deployment to deploy all the
# required resources for Notary v2 - remote signing and verification with 
# Notation, Gatekeeper, Ratify, and AKS.

# Requirements:
# Git
# Azure CLI (log in)
# Helm
# Kubectl

# Get the latest version of Kubernetes available in specified location
function getLatestK8s {
   versions=$(az aks get-versions -l $location -o tsv --query="orchestrators[].orchestratorVersion")

   latestVersion=$(printf '%s\n' "${versions[@]}" |
   awk '$1 > m || NR == 1 { m = $1 } END { print m }')

   echo $latestVersion
}

# Environment variables / positional parameters and defaults. 

# TODO make $1 and $2 required?
keyName=$1

keySubjectName=$2

rgName=$3
rgName=${rgName:-myakv-akv-rg}

# The location to store the meta data for the deployment.
location=${location:-southcentralus} # Currently only region to support premium ACR with Zone Redundancy

# The version of k8s control plane
k8sversion=$4
k8sversion=${k8sversion:-$(getLatestK8s)}

# Environment Name (ACR, AKS, KV prefix)
envPrefix=$5
envPrefix=${envPrefix:-myakv}

# Install Notation CLI
function getNotationProject {
    echo ''
    echo "Setting up the Notation CLI..."

    # Grab OS Version
    osVersion=$(uname | tr '[:upper:]' '[:lower:]')

    # Choose a binary
    timestamp=20220121081115
    commit=17c7607

    # Download Notation from pre-release
    curl -Lo notation.tar.gz https://github.com/notaryproject/notation/releases/download/feat-kv-extensibility/notation-feat-kv-extensibility-$timestamp-$commit.tar.gz

    # Extract notation
    mkdir ./tmp
    tar xvzf notation.tar.gz -C ./tmp

    # Copy the notation cli to your bin directory
    tar xvzf ./tmp/notation_0.0.0-SNAPSHOT-${commit}_${osVersion}_amd64.tar.gz -C ~/bin notation

    # Clean up
    rm -rf ./tmp notation.tar.gz
}

# Install Azure Keyvault Plugin
function installNotationKvPlugin {
    echo ''
    echo "Setting up the Notation Keyvault Plugin..."

    # Create a directory for the plugin
    mkdir -p ~/.config/notation/plugins/azure-kv

    # Download the plugin
    curl -Lo notation-azure-kv.tar.gz \
        https://github.com/Azure/notation-azure-kv/releases/download/v0.1.0-alpha.1/notation-azure-kv_0.1.0-alpha.1_Linux_amd64.tar.gz

    # Extract to the plugin directory    
    tar xvzf notation-azure-kv.tar.gz -C ~/.config/notation/plugins/azure-kv notation-azure-kv

    # Add Azure Keyvault plugin to notation
    notation plugin add azure-kv ~/.config/notation/plugins/azure-kv/notation-azure-kv

    # List Notation plugins
    notation plugin ls

    # Clean up
    rm -rf notation-azure-kv.tar.gz
}

function installGatekeeper {
    echo ''
    echo "Configuring Gatekeeper on your AKS Cluster..."

    # Add gatekeeper repo to Helm
    helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts

    # Install Gatekeeper on AKS Cluster
    helm install gatekeeper/gatekeeper  \
        --name-template=gatekeeper \
        --namespace gatekeeper-system --create-namespace \
        --set enableExternalData=true \
        --set controllerManager.dnsPolicy=ClusterFirst,audit.dnsPolicy=ClusterFirst
}

function createSigningCertforKV {
    echo ''
    echo "Generating signing cert..."
    # TODO: Add signing

    # Create the certificate in Azure KeyVault
    az keyvault certificate create -n $rgName --vault-name $aksName -p @my_policy.json

    # Get the Key ID for the newly created Cert
    keyID=$(az keyvault certificate show --vault-name $keyVaultName \
            --name $keyName \
            --query "kid" -o tsv)
    
    # Use notation to add the key id to the kms keys and certs
    notation key add --name $keyName --plugin azure-kv --id $keyID --kms
    notation cert add --name $keyName --plugin azure-kv --id $keyID--kms

    # Checks and balances
    notation key ls
    notation cert ls
}

function secureAKSwithRatify {
    echo ''
    echo "Configuring Ratify on your AKS cluster..."
    PUBLIC_KEY=$(az keyvault certificate show -n $keyName \
                --vault-name $keyVaultName \
                -o json | jq -r '.cer' | base64 -d | openssl x509 -inform DER)

    # Temporary, until the ratify chart is published
    git clone https://github.com/deislabs/ratify.git $HOME/ratify

    helm install ratify $HOME/ratify/charts/ratify \
        --set registryCredsSecret=regcred \
        --set ratifyTestCert=$PUBLIC_KEY

    kubectl apply -f $HOME/ratify/charts/ratify-gatekeeper/templates/constraint.yaml

    # Clean up
    rm -rf $HOME/ratify
}

# Build Image and Sign it
function bulidImageandSign {
    echo ''
    echo "Testing signing of image..."
    # TODO: Add Test

    # Build and Push a new image using ACR Tasks
    az acr build -r $acrName -t $IMAGE $IMAGE_SOURCE

    # Sign the container image once built
    notation sign --key $keyName $IMAGE

    # Deploy the newly signed image
    kubectl create namespace $NAMESPACE
    kubectl run test-deploy --image=$IMAGE -n $NAMESPACE
}

# Get outputs of Azure Deployment
function getOutput {
   echo $(az deployment sub show --name $rgName --query "properties.outputs.$1.value" --output tsv)
}

# Deploy AKS, ACR, and Keyvault with Bicep
function deployInfra {
    echo ''
    echo "Deploying the required infrastructure..."

    # Deploy the infrastructure
    az deployment sub create --name $rgName \
    --location $location \
    --template-file ./iac/main.bicep \
    --parameters rgName=$rgName \
    --parameters location=$location \
    --parameters k8sversion=$k8sversion \
    --parameters envPrefix=$envPrefix \
    --output none

    # Check for success
    if [[ $? -eq 1 ]]
    then
        echo ''
        echo "Something went wrong."
        exit 1
    else 
        # Get all the outputs
        aksName=$(getOutput 'aks_name')
        acrName=$(getOutput 'acr_name')
        keyVaultName=$(getOutput 'keyVault_name')

        # Add new cluster to local Kube Config
        echo ''
        echo "Adding newly created Kubernetes context to your Kube Config..."
        az aks get-credentials -n $aksName -g $rgName --admin
    fi
}

function setup {
    getNotationProject
    installNotationKvPlugin
    deployInfra
    installGatekeeper
    # createSigningCertforKV
    # secureAKSwithRatify
    # bulidImageandSign
}

# Call setup function
setup

# TODO: Add support for pre-existing infrastructure
