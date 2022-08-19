terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-west-2"
}

variable "iplz_img_path" {
  description = "Path to the server image."
  type        = string
}

output "public_ip" {
  value = aws_instance.iplz_server.public_ip
}

resource "aws_instance" "iplz_server" {
  ami                    = aws_ami.iplz_ami.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.iplz_security_group.id]
}

resource "aws_security_group" "iplz_security_group" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ami" "iplz_ami" {
  name                = "iplz_server_ami"
  virtualization_type = "hvm"
  root_device_name    = "/dev/xvda"
  ebs_block_device {
    device_name = "/dev/xvda"
    snapshot_id = aws_ebs_snapshot_import.iplz_import.id
  }
}

resource "aws_s3_bucket" "iplz_bucket" {}

resource "aws_s3_bucket_acl" "iplz_acl" {
  bucket = aws_s3_bucket.iplz_bucket.id
  acl    = "private"
}

resource "aws_s3_object" "image_upload" {
  bucket = aws_s3_bucket.iplz_bucket.id
  key    = "iplz.vhd"
  source = var.iplz_img_path
}

resource "aws_ebs_snapshot_import" "iplz_import" {
  role_name = aws_iam_role.vmimport_role.id
  disk_container {
    format = "VHD"
    user_bucket {
      s3_bucket = aws_s3_bucket.iplz_bucket.id
      s3_key    = aws_s3_object.image_upload.id
    }
  }
  lifecycle {
    replace_triggered_by = [
      aws_s3_object.image_upload
    ]
  }
}

resource "aws_iam_role_policy_attachment" "vmpimport_attach" {
  role       = aws_iam_role.vmimport_role.id
  policy_arn = aws_iam_policy.vmimport_policy.arn
}

resource "aws_iam_role" "vmimport_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "vmie.amazonaws.com" }
        Action    = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:Externalid" = "vmimport"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "vmimport_policy" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetBucketAcl"
        ]
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.iplz_bucket.id}",
          "arn:aws:s3:::${aws_s3_bucket.iplz_bucket.id}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:ModifySnapshotAttribute",
          "ec2:CopySnapshot",
          "ec2:RegisterImage",
          "ec2:Describe*"
        ],
        Resource = "*"
      }
    ]
  })
}
