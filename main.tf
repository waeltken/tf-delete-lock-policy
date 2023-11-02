provider "azurerm" {
  features {}
}

resource "azurerm_policy_definition" "lock" {
  name         = "CreateDeleteLockOnTag"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "CreateDeleteLockOnTag"
  description  = "This policy locks a resource group when the delete_lock=true tag is applied to it."

  policy_rule = <<POLICY_RULE
{  
  "if": {  
    "field": "tags['delete_lock']",  
    "equals": "true"  
  },  
  "then": {  
    "effect": "deployIfNotExists",  
    "details": {  
      "type": "Microsoft.Authorization/locks",  
      "roleDefinitionIds": [  
        "/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"  
      ],  
      "existenceCondition": {  
        "field": "Microsoft.Authorization/locks/level",  
        "equals": "CanNotDelete"  
      },  
      "deployment": {  
        "properties": {  
					"mode": "incremental",
          "parameters": {  
            "lockName": {  
              "value": "[concat(resourceGroup().name, '-', 'delete_lock')]"  
            },  
            "lockLevel": {  
              "value": "CanNotDelete"  
            },  
            "lockNotes": {  
              "value": "This resource has been locked by policy"  
            }  
          },  
          "template": {  
            "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",  
            "contentVersion": "1.0.0.0",  
            "parameters": {  
              "lockName": {  
                "type": "string"  
              },  
              "lockLevel": {  
                "type": "string"  
              },  
              "lockNotes": {  
                "type": "string"  
              }  
            },  
            "resources": [  
              {  
                "type": "Microsoft.Authorization/locks",  
                "apiVersion": "2016-09-01",  
                "name": "[parameters('lockName')]",  
                "properties": {  
                  "level": "[parameters('lockLevel')]",  
                  "notes": "[parameters('lockNotes')]" 
                }  
              }  
            ]  
          }  
        }  
      }  
    }  
  }  
}  
POLICY_RULE
}


# Example on how to assign the policy definition to a subscription
data "azurerm_subscription" "current" {}

resource "azurerm_subscription_policy_assignment" "sample_assignment" {
  name                 = "${azurerm_policy_definition.lock.name}_assignment"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = azurerm_policy_definition.lock.id
  location             = "West Europe"
  # The identity block is required to create a system assigned identity for the policy assignment
  identity {
    type = "SystemAssigned"
  }
}

# The role assignment is required to grant the policy assignment the required permissions to create the lock.
# Only the Owner and User Access Administrator roles can create locks.
resource "azurerm_role_assignment" "lock_role" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "User Access Administrator"
  principal_id         = azurerm_subscription_policy_assignment.sample_assignment.identity[0].principal_id
}

