output "clickhouse_backups_bucket_id" {
  value = data.aws_s3_bucket.clickhouse.id
}

output "clickhouse_backups_bucket" {
  value = data.aws_s3_bucket.clickhouse
}

output "service" {
  value = "clickhouse.clickhouse.svc.cluster.local"
}
