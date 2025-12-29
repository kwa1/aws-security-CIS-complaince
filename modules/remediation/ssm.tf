resource "aws_ssm_document" "block_s3_public" {
  name          = "BlockPublicS3Access"
  document_type = "Automation"

  content = jsonencode({
    schemaVersion = "0.3"
    mainSteps = [{
      action = "aws:executeAwsApi"
      name   = "blockAccess"
      inputs = {
        Service = "s3control"
        Api     = "PutPublicAccessBlock"
      }
    }]
  })
}
