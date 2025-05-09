output "clickhouse_backups_url" {
  value = "s3://${data.aws_s3_bucket.clickhouse.id}/backups"
}

output "service" {
  value = "clickhouse.clickhouse.svc.cluster.local"
}
