package aws.s3.security

test_encrypted_bucket_allowed if {
  count(deny) == 0 with input as {
    "resource_type": "aws_s3_bucket",
    "server_side_encryption_configuration": {
      "rule": {
        "apply_server_side_encryption_by_default": {
          "sse_algorithm": "AES256"
        }
      }
    }
  }
}

test_unencrypted_bucket_denied if {
  count(deny) > 0 with input as {
    "resource_type": "aws_s3_bucket"
  }
}

test_public_read_bucket_denied if {
  count(deny) > 0 with input as {
    "resource_type": "aws_s3_bucket",
    "acl": "public-read",
    "server_side_encryption_configuration": {
      "rule": {
        "apply_server_side_encryption_by_default": {
          "sse_algorithm": "AES256"
        }
      }
    }
  }
}