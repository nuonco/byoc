output "secrets" {
  value = [
    for key, instance in module.secrets : merge(
      { name = key },
      {
        for output_key, output_value in instance : output_key => output_value
      }
    )
  ]
  description = "A list of objects where each object contains all outputs from a secrets module instance."
}
