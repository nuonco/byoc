locals {
  resource_group_scope = format(
    "/subscriptions/%s/resourceGroups/%s",
    var.subscription_id,
    var.resource_group_name,
  )
}

resource "azurerm_role_assignment" "maintenance_rg_contributor" {
  count = var.maintenance_principal_object_id == "" ? 0 : 1

  scope                = local.resource_group_scope
  role_definition_name = "Contributor"
  principal_id         = var.maintenance_principal_object_id
}

resource "azurerm_role_assignment" "maintenance_aks_cluster_admin" {
  count = var.maintenance_principal_object_id == "" ? 0 : 1

  scope                = var.aks_cluster_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = var.maintenance_principal_object_id
}

resource "azurerm_role_assignment" "break_glass_rg_contributor" {
  count = var.break_glass_principal_object_id == "" ? 0 : 1

  scope                = local.resource_group_scope
  role_definition_name = "Contributor"
  principal_id         = var.break_glass_principal_object_id
}

resource "azurerm_role_assignment" "break_glass_aks_cluster_admin" {
  count = var.break_glass_principal_object_id == "" ? 0 : 1

  scope                = var.aks_cluster_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = var.break_glass_principal_object_id
}
