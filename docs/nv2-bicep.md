# Notary v2 - Remote Signing and Verification with Gatekeeper, Ratify and AKS

## Install the notation cli and azure-kv plugin

Starting from the root of this repo, make sure you are logged into the Azure CLI. This is a pre-requisite.

  ```bash
  az login
  ```

Set the desired subscription.

  ```bash
  az account set --subscription <id or name>
  ```

Once you have done the above, you are ready to deploy the required infrastructure by running the provided `setup.sh` script. You can provide the following arguements in the following order for the script:

1. Key Name: **Required** Key name used to sign and verify.
2. Key Subject Name: **Required** Key subejct name used to sign and verify.
3. Resource Group Name: This will be the resource group created in Azure. If you do not provide a value `myakv-akv-rg` will be used.
4. Location: This is the location to deploy all your resources. If you do not provide a value `eastus` will be used.
5. Kubernetes Version: This is the version of Kubernetes control plane. If you do not provide a value, the latest Kubernetes version available for the provided location will be used.
6. Environment Prefix: This is the prefix for the required resources that will be created for you. If you do not provide a value, `myakv` will be used.

Bash

  ```bash
  ./setup.sh keyName keySubjectName myAkvDeploy eastus '1.21.2' akvResources
  ```

### Known Issues / Currently Working on:

1. ~~Add installGatekeeper Function~~
2. Add createSigningCertforKv Function
3. Add buildImageandSign Function
4. Add support for pre-existing infrastructure (as of right now, this stands everything up from scratch in a brand new resource group)