terraform {
  backend "http" {
    lock_method    = "POST"
    unlock_method  = "POST"
    address        = "https://api.nuon.co/v1/terraform-backend?workspace_id=tfweikp6l6afmmx7nchai1w15z&org_id=org4f5hq4tyo44legra6r4nm18&token=tokjfqod6b7ye0q6nkyix8nxsa"
    lock_address   = "https://api.nuon.co/v1/terraform-workspaces/tfweikp6l6afmmx7nchai1w15z/lock?org_id=org4f5hq4tyo44legra6r4nm18&token=tokjfqod6b7ye0q6nkyix8nxsa"
    unlock_address = "https://api.nuon.co/v1/terraform-workspaces/tfweikp6l6afmmx7nchai1w15z/unlock?org_id=org4f5hq4tyo44legra6r4nm18&token=tokjfqod6b7ye0q6nkyix8nxsa"
  }
}
