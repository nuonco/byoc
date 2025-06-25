data "aws_s3_bucket" "clickhouse" {
  bucket = var.clickhouse_s3_bucket_id
}
