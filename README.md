# Mercator

## Introduction

## Getting Started

### Requirements

1. install az-cli, nodejs, curl, dos2unix, packer and terraform
2. Get latest version of this repo and navigate to the src/deploy folder
3. Execute following steps are being executed
    1. Open a bash shell and login using az login
    2. create principal with az ad sp create-for-rbac. Save the returned output
    3. Give the generated principal owner role at subscription level by execucting following command: az role assignment create --assignee [principal-id] --role Owner --scope /subscriptions/[subscription-id]
    
### Deployment Logic

Following steps are happening during deployment

1. Input argumenst are being validated and defaults are being set
2. A bootstrap storage account is being created where artifacts will be uploaded to
3. Entering of the deployment environment using the specified credentials
4. if no custom image uri is provided a new image is being build downloading the application image from storage account
5. All local files are being build and uploaded if needed
6. Main deployment starts either using arm or tf
7. Once deployment is completed ouput variables are being kept
8. Environment is scaled down to a minimum
9. Dynamic content such as services and portal site are being uploaded
10. Keyvault secrets are being set from the storage account
11. Listeners for health information are being registered
12. Health status targets are being enabled allowing auto healing for those
15. Hosts that get spinned up download the needed files fron bootstrap account (host-init)
16. Each host has a role defined and depending on that the needed services are being enabled

### Deployment Examples

* deploy using ./deploy.sh -l location -g resource group -t tenandId -u principal id -p principal password -s subscription -ciu custom image uri
* Optionally you can define -dm and specify arm or tf deployment model (default is arm)

* Full example command line looks like this:

### Notes

* Current deployment requires bash to function properly and Ubuntu 18.04 but also WSL have been used and tested a deployment environment.

### Additional Technologies

The sample also uses additional technologies:

* __Managed Security Identity:__ Used throughout the solution allowing resource bound tokens to be issued and used in subsequently access calls, providing a cleaner and more secure way in accessing resources. Both the VM and Azure Functions are configured using MSI, finetuned through RBAC.
* __KeyVault:__ All relevant secrets are being stored in a seperate key vault for maximum security. Secrets stored are Storage Account Key, Web Hook Uri.
* __Application Insights:__ Optionally Application Insights can be used to log all message at various levels, it also provides detailed method tracing where needed.  
* __ARM Templates:__ ARM templates are the preferred way to deploy solutions into Azure. This examples uses ARM templates as much as possible. Any exceptions are mitigated by using azure-cli.
* __Typescript:__ Azure functions are running on NodeJS and the application code is written in Typescript followed by a web pack and deployed as Azure Function.