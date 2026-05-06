package aws.s3.security

deny contains msg if {
  input.resource_type == "aws_s3_bucket"
  not input.server_side_encryption_configuration
  msg := "S3 buckets must have server-side encryption enabled"
}

deny contains msg if {
  input.resource_type == "aws_s3_bucket"
  input.acl == "public-read"
  msg := "S3 buckets must not use public-read ACL"
}
