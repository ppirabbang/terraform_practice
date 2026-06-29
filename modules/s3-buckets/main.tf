#26. 로그 저장용 s3 버킷 생성
resource "aws_s3_bucket" "audit"{
  bucket = "${var.name_prefix}-audit-log-12345"
  force_destroy = true

  tags = {
    Name = "${var.name_prefix}-audit"
  }
}

#27. 버킷 퍼블릭 차단
resource "aws_s3_bucket_public_access_block" "audit"{
  bucket = aws_s3_bucket.audit.id

  block_public_acls = true
  ignore_public_acls = true
  block_public_policy = true
  restrict_public_buckets = true
} 

#28. cloudtrail 이 s3에 쓸 수 있도록
resource "aws_s3_bucket_policy" "audit"{
  bucket = aws_s3_bucket.audit.id
  policy = data.aws_iam_policy_document.cloudtrail_to_s3.json
}

data "aws_iam_policy_document" "cloudtrail_to_s3" {
  statement {
    sid = "AWSCloudTrailAclCheck"
    effect = "Allow"
    actions = ["s3:GetBucketAcl"]
    principals {
      type = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    resources = [aws_s3_bucket.audit.arn]
  }

  statement {
    sid = "AWSCloudTrailWrite"
    effect = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    resources = ["${aws_s3_bucket.audit.arn}/*"]
  }
}