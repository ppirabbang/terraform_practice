output "audit_bucket" {
  value = aws_s3_bucket.audit.bucket
}

output "audit_bucket_arn" {
  value = aws_s3_bucket.audit.arn
}

output "audit_bucket_policy_id" {
  value = aws_s3_bucket_policy.audit.id
}