resource "aws_cloudtrail" "this" {

  depends_on = [var.audit_bucket_policy_id] # 정책 먼저 생성
  # s3 module에 output으로 해당 값이 선언되어 있어서 사용 가능

  name = "${var.name_prefix}-trail"
  s3_bucket_name = var.audit_bucket
 
  include_global_service_events = true
  is_multi_region_trail = true
  enable_logging = true

  event_selector {
    read_write_type = "All"
    include_management_events = true
  }
}
