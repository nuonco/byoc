cluster_image_repository = "{{ .nuon.sandbox.outputs.acr.login_server }}/{{ .nuon.components.img_clickhouse_server.outputs.image.repository }}"
cluster_image_tag = "{{ .nuon.components.img_clickhouse_server.outputs.image.tag }}"

keeper_image_repository = "{{ .nuon.sandbox.outputs.acr.login_server }}/{{ .nuon.components.img_clickhouse_keeper.outputs.image.repository }}"
keeper_image_tag = "{{ .nuon.components.img_clickhouse_keeper.outputs.image.tag }}"
