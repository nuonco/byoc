output "clickhouse_backups_url" {
  value = "s3://${data.aws_s3_bucket.id}/backups"
}

output "service" {
  value = "clickhouse.clickhouse.svc.cluster.local"
}
