provider "archive" {
  version = "~> 1.1"
}

provider "random" {
  version = "~> 2.0"
}

provider "template" {
  version = "~> 2.0"
}

provider "aws" {
  version = "~> 2.17.0"
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

module "ses_domain" {
  source  = "trussworks/ses-domain/aws"
  version = "1.0.1"

  domain_name       = "${var.domain_name}"
  mail_from_domain  = "email.${var.domain_name}"
  route53_zone_id   = "${var.aws_zone_id}"
  from_addresses    = ["${var.from_addresses}"]
  dmarc_rua         = "${var.dmarc_rua}"
  receive_s3_bucket = "${aws_s3_bucket.mail.id}"
  receive_s3_prefix = "inbound"
  ses_rule_set      = "the_rules"
}

resource "aws_ses_receipt_rule_set" "the_rules" {
  rule_set_name = "the_rules"
}

resource "aws_ses_active_receipt_rule_set" "main" {
  rule_set_name = "the_rules"

  depends_on = ["aws_ses_receipt_rule_set.the_rules"]
}

# https://docs.aws.amazon.com/ses/latest/DeveloperGuide/receiving-email-permissions.html
resource "aws_s3_bucket" "mail" {
  bucket = "${var.s3_bucket}"
  acl    = "private"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowSESPuts",
            "Effect": "Allow",
            "Principal": {
                "Service": "ses.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${var.s3_bucket}/*",
            "Condition": {
                "StringEquals": {
                    "aws:Referer": "${data.aws_caller_identity.current.account_id}"
                }
            }
        }
    ]
}
POLICY
}

resource "aws_s3_bucket_metric" "mail" {
  bucket = "${aws_s3_bucket.mail.bucket}"
  name   = "EntireBucket"
}

data "aws_caller_identity" "current" {}
