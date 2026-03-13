output "maintenance_role_assignment_ids" {
  value = compact([
    try(azurerm_role_assignment.maintenance_rg_contributor[0].id, ""),
    try(azurerm_role_assignment.maintenance_aks_cluster_admin[0].id, ""),
  ])
}

output "break_glass_role_assignment_ids" {
  value = compact([
    try(azurerm_role_assignment.break_glass_rg_contributor[0].id, ""),
    try(azurerm_role_assignment.break_glass_aks_cluster_admin[0].id, ""),
  ])
}
