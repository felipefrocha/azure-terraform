provider "azurerm" {
  # Whilst version is optional, we /strongly recommend/ using it to pin the version of the Provider being used
  version = "~>2.5.0"
  features {}
}

terraform {
  backend "azurerm" {}
}

resource "azurerm_resource_group" "rg" {
  name     = "resourceGroup1"
  location = "West US"
}

resource "azurerm_container_registry" "acr" {
  name                = "cemedacr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard"
  admin_enabled       = true
  #   georeplication_locations = ["East US"]
}


resource "azurerm_container_group" "container" {
  name                = "cemedacr-continst"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  ip_address_type     = "public"
  dns_name_label      = "aci-label"
  os_type             = "Linux"

  /*  image_registry_credential {
      username = azurerm_container_registry.acr.admin_username
      password = azurerm_container_registry.acr.admin_password
      server =  azurerm_container_registry.acr.login_server
  }

  container {
    name   = "hello-world"
    image  = "cemedacr.azurecr.io/reservation:v1"
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 80
      protocol = "TCP"
    }
  }*/

  container {
    name   = "hello-world"
    image  = "microsoft/azure-vote-front:cosmosdb"
    cpu    = "0.5"
    memory = "1.5"

    environment_variables = {
      COSMOS_DB_ENDPOINT   = azurerm_cosmosdb_account.cosmosdb.endpoint
      COSMOS_DB_MASTER_KEY = azurerm_cosmosdb_account.cosmosdb.primary_master_key
    }

    ports {
      port     = 80
      protocol = "TCP"
    }
  }

  tags = {
    environment = "testing"
  }
}

resource "random_integer" "ri" {
  max = 99999
  min = 90000
}

resource "azurerm_cosmosdb_account" "cosmosdb" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  name                = format("rfex-cosmos-db-%d", random_integer.ri.result)
  offer_type          = "Standard"
  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 10
    max_staleness_prefix    = 200
  }
  geo_location {
    failover_priority = 0
    location          = azurerm_resource_group.rg.location
  }
}

output "container_id" {
  value = {
    ip       = azurerm_container_group.container.ip_address
    username = azurerm_container_registry.acr.admin_username
    password = azurerm_container_registry.acr.admin_password
    server   = azurerm_container_registry.acr.login_server
  }
}

output "cosmos_db" {
  value = {
    db_name      = ""
    db_endpoint  = ""
    db_masterkey = ""
  }
}