# Gerenciamento do Terraform State

Essa pasta dedica se a montar o gerencimento remoto do estado do Terraform de modo a viabilizar seu uso pela equipe.
O *state* do terraform é um arquivo de configuração de todos os recursos e sua representação atualizada com a instancia gerida na plataforma.

Não sendo essa auto gerenciavel, é necessário que para sua correta utilização pela equipe e/ou por ferramentas de automação como CI e CD, seja configurado um gerenciador remoto desse estado e além disso a configuração de uma solicitação de uso, para evitar condições de corrida e utilização impropria do estado por mais de um usuário.

## Autenticação CLI

Para utilizar o Terraform de maineira mais segura é necessário configurar o ambinete onde o binario que interpreta o codigo de extensão `*.tf` irá ser executado.

Existem diversos métodos de configuração das credenciais para serem utilizados sendo eles:

* [Autenticação Azure CLI](https://www.terraform.io/docs/providers/azurerm/guides/azure_cli.html)
* [Autenticação Azure Gerenciador de serviços de identidade](https://www.terraform.io/docs/providers/azurerm/guides/managed_service_identity.html)
* [Autenticação Azure por certificado de serviço e cliente](https://www.terraform.io/docs/providers/azurerm/guides/service_principal_client_certificate.html)
* [Autenticação Azure por chave secreta de cliente e serviço](https://www.terraform.io/docs/providers/azurerm/guides/service_principal_client_secret.html)


Por opção de simplicidade e pela possibilidade de uso em ferramentas de automação do deploy de infraestrutura. Vamos optar pelo usuo do 3º método.

### Autenticação 
```shell

az login --tenant <tenant id>

# Retornando :
# [
#   {
#     "cloudName": "AzureCloud",
#     "id": "00000000-0000-0000-0000-000000000000",
#     "isDefault": false,
#     "name": "N/A(tenant level account)",
#     "state": "Enabled",
#     "tenantId": "00000000-0000-0000-0000-000000000000",
#     "user": {
#       "name": "<user>",
#       "type": "user"
#     }
#   }
# ]

az account set --subscription="SUBSCRIPTION_ID" # Registro de subscription

az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/SUBSCRIPTION_ID" # Registro de role editor de recursos

# Retornando :
# {
#   "appId": "00000000-0000-0000-0000-000000000000",
#   "displayName": "azure-cli-2020-06-13-22-03-43",
#   "name": "http://azure-cli-2020-06-13-22-03-43",
#   "password": "00000000-00_00000000000000.000",
#   "tenant": "00000000-0000-0000-0000-000000000000"
# }
```
Considerando :

* appId ->  client_id 
* password ->  client_secret 
* tenant ->  tenant_id  

```shell
#!/bin/bash

az login --service-principal -u CLIENT_ID -p CLIENT_SECRET --tenant TENANT_ID

# Retornando: 
# {
#     "cloudName": "AzureCloud",
#     "homeTenantId": "00000000-0000-0000-0000-000000000000",
#     "id": "00000000-0000-0000-0000-000000000000",
#     "isDefault": true,
#     "managedByTenants": [],
#     "name": "Azure for Students",
#     "state": "Enabled",
#     "tenantId": "00000000-0000-0000-0000-000000000000",
#     "user": {
#       "name": "00000000-0000-0000-0000-000000000000",
#       "type": "servicePrincipal"
#     }
#   }

```

Podemos configurar o *provider* da *Azure* da seguinte forma:

```terraform
provider "azurerm" {
  # Whilst version is optional, we /strongly recommend/ using it to pin the version of the Provider being used
  version = "=2.5.0"
  features {}
}

# Ou

variable "client_secret" {
}

provider "azurerm" {
  version = ">~2.5.0"

  subscription_id = "00000000-0000-0000-0000-000000000000"
  client_id       = "00000000-0000-0000-0000-000000000000"
  client_secret   = var.client_secret
  tenant_id       = "00000000-0000-0000-0000-000000000000"

  features {}
}


```

## Beckend

Pra cada provider esse gerenciamento pode ser realizado de forma específica. Sendo melhor utilizar uma ferramenta agnostica como o Terraform Cloud, ou mesmo uma que utilize recursos do *privider* utilizado.

Vamos tentar simplificar. 

Para a gestão do estado dos recursos utilizados pela ***<empresa>***, vamos utilizar o provedor da **Azure**, sendo assim a configuração do gestor de estado remoto que escolheremos para ser utilizado no terraform será o **azurerm**.

### Configurando o Backend repositorio

```shell
#!/bin/bash
ENVIRONMENT=dev
RESOURCE_GROUP_NAME=tfstate
STORAGE_ACCOUNT_NAME=tfstate$RANDOM
CONTAINER_NAME=tfstate

# Create resource group
az group create --name $RESOURCE_GROUP_NAME --location eastus

# Create storage account
az storage account create --resource-group $RESOURCE_GROUP_NAME --name $STORAGE_ACCOUNT_NAME --sku Standard_LRS --encryption-services blob

# Get storage account key
ACCOUNT_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP_NAME --account-name $STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv)

# Create blob container
az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME --account-key $ACCOUNT_KEY

echo "storage_account_name: $STORAGE_ACCOUNT_NAME"
echo "container_name: $CONTAINER_NAME"
echo "access_key: $ACCOUNT_KEY"

cat << EOF > $ENVIRONMENT.backend.tfvars
resource_group_name   = "$RESOURCE_GROUP_NAME"
storage_account_name  = "$STORAGE_ACCOUNT_NAME"
container_name        = "$CONTAINER_NAME"
key                   = "$ENVIRONMENT.terraform.tfstate"
EOF
```

A configuração do mesmo se dá pelo código a seguir
```terraform
provider "azurerm" {
    version = "~>2.0.0"
}

terraform {
    backend {}
}
```

### Arquivos de configuração.