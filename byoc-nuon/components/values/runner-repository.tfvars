# passthrough from the sandbox; the public runner repo lives alongside the
# private app ecr provisioned by the sandbox.
ecr = {
  id  = "{{ .nuon.sandbox.outputs.ecr.registry_id }}"
  arn = "{{ .nuon.sandbox.outputs.ecr.repository_arn }}"
}
