#!/bin/bash
# This script will run an ARM template deployment to deploy all the
# required resources for Notary v2 - remote signing and verification with 
# Notation, Gatekeeper, Ratify, and AKS.

# Requirements:
# Git
# Azure CLI (log in)

# Store current working directory
currentDir=$(pwd)

# Get the latest version of Kubernetes available in specified location
function getLatestK8s {
   versions=$(az aks get-versions -l $location -o tsv --query="orchestrators[].orchestratorVersion")

   latestVersion=$(printf '%s\n' "${versions[@]}" |
   awk '$1 > m || NR == 1 { m = $1 } END { print m }')

   echo $latestVersion
}

# The name of the resource group to be created. All resources will be place in
# the resource group and start with name.
rgName=$1
rgName=${rgName:-myakv-akv-rg}

# The location to store the meta data for the deployment.
location=$2
location=${location:-eastus}

# The version of k8s control plane
k8sversion=$3
k8sversion=${k8sversion:-$(getLatestK8s)}

# Environment Name (ACR, AKS, KV prefix)
envPrefix=$4
envPrefix=${envPrefix:-myakv}

# Install Notation CLI
function getNotationProject {
    echo ''
    echo "Setting up the Notation CLI..."
    # Get Notation project from Keyvault Extensibilty Branch
    git clone https://github.com/notaryproject/notation.git -b feat-kv-extensibility $HOME/notation
    cd $HOME/notation
    make build

    # Copy the notation cli to your bin directory
    cp ./bin/notation ~/bin

    # Clean up
    rm -rf $HOME/notation
}

# Install Azure Keyvault Plugin
function installNotationKvPlugin {
    echo ''
    echo "Setting up the Notation Keyvault Plugin..."
    # Change directories back to current working directory

    cd $currentDir
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

function createServicePrincipal {
    # Service Principal Name
    SP_NAME=https://${envPrefix}-sp

    # Create the service principal, capturing the password
    export AZURE_CLIENT_SECRET=$(az ad sp create-for-rbac --skip-assignment --name $SP_NAME --query "password" --output tsv)

    # Capture the service srincipal appId
    export AZURE_CLIENT_ID=$(az ad sp list --display-name $SP_NAME --query "[].appId" --output tsv)

    # Capture the Azure Tenant ID
    export AZURE_TENANT_ID=$(az account show --query "tenantId" -o tsv)
}

function installGatekeeper {
    echo ''
    echo "Configuring Gatekeeper on your AKS Cluster..."
    # TODO: Add Gatekeeper 
}

function createSigningCertforKV {
    echo ''
    echo "Generating signing cert..."
    # TODO: Add signing
}

function secureAKSwithRatify {
    echo ''
    echo "Configuring Ratify on your AKS cluster..."
    # TODO: Add Ratify
}

# Build Image and Sign it
function bulidImageandSign {
    echo ''
    echo "Testing signing of image..."
    # TODO: Add Test
}

# Get outputs of Azure Deployment
function getOutput {
   echo $(az deployment sub show --name $rgName --query "properties.outputs.$1.value" --output tsv)
}

# Deploy AKS, ACR, and Keyvault with Bicep
function deployInfra {
    echo ''
    echo "Deploying the required infrastructure..."
    cd $currentDir
    # Deploy the infrastructure
    az deployment sub create --name $rgName \
    --location $location \
    --template-file ./iac/main.bicep \
    --parameters rgName=$rgName \
    --parameters location=$location \
    --parameters k8sversion=$k8sversion \
    --parameters envPrefix=$envPrefix \
    --output none

    # Get all the outputs
    aksName=$(getOutput 'aks_name')
}

function setup {
    getNotationProject
    installNotationKvPlugin
    deployInfra
    installGatekeeper
    createSigningCertforKV
    secureAKSwithRatify
    bulidImageandSign
}

# Call setup function
setup

# TODO: Add support for pre-existing infrastructure
