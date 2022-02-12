data "aws_iam_policy_document" "firehose_es_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type = "Service"
      identifiers = [
        "firehose.amazonaws.com",
      ]
    }
  }
}
data "aws_iam_policy_document" "firehose_assume_role" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type = "Service"
      identifiers = [
        "firehose.amazonaws.com",
      ]
    }
  }
}
data "aws_iam_policy_document" "firehose_opensearch_policy_document" {
  statement {
    effect  = "Allow"
    actions = ["es:*"]
    resources = [
      aws_elasticsearch_domain.es_domain.arn,
      "${aws_elasticsearch_domain.es_domain.arn}/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:CreateNetworkInterfacePermission",
      "ec2:DeleteNetworkInterface"
    ]
    resources = ["*"]
  }
  // needed for s3_configuration to drop error logs into
  statement {
    effect = "Allow"
    actions = [
      "s3:List*",
      "s3:GetObject",
      "s3:Put*"
    ]
    resources = [
      aws_s3_bucket.osquery-results.arn,
      "${aws_s3_bucket.osquery-results.arn}/*"
    ]
  }
}

resource "aws_iam_role" "firehose_role_es" {
  name               = "opensearch_firehose_role"
  assume_role_policy = data.aws_iam_policy_document.firehose_es_policy_doc.json
}

resource "aws_iam_policy" "firehose_opensearch" {
  name   = "firehose_iam_policy"
  policy = data.aws_iam_policy_document.firehose_opensearch_policy_document.json
}

resource "aws_iam_role_policy_attachment" "firehose_opensearch" {
  policy_arn = aws_iam_policy.firehose_opensearch.arn
  role       = aws_iam_role.firehose_role_es.name
}

resource "aws_iam_role_policy" "firehose_role_policy" {
  name   = "firehose_os_role_policy"
  policy = data.aws_iam_policy_document.firehose_opensearch_policy_document.json
  role   = aws_iam_role.firehose_role_es.name
}

resource "aws_iam_policy" "firehose_s3" {
  name   = "firehose_os_iam_policy"
  policy = data.aws_iam_policy_document.firehose_opensearch_policy_document.json
}
resource "aws_iam_role_policy_attachment" "firehose_s3" {
  policy_arn = aws_iam_policy.firehose_s3.arn
  role       = aws_iam_role.firehose_role_s3.name
}
resource "aws_iam_role" "firehose_role_s3" {
  assume_role_policy = data.aws_iam_policy_document.firehose_assume_role.json
}


resource "aws_kinesis_firehose_delivery_stream" "main" {
  depends_on  = [aws_iam_role_policy.firehose_role_policy, aws_elasticsearch_domain.es_domain]
  name        = "firehose_osquery_opensearch"
  destination = "elasticsearch"

  s3_configuration {
    role_arn           = aws_iam_role.firehose_role_es.arn
    bucket_arn         = aws_s3_bucket.osquery-results.arn
    buffer_size        = 10
    buffer_interval    = 400
    compression_format = "GZIP"
  }

  elasticsearch_configuration {
    domain_arn = aws_elasticsearch_domain.es_domain.arn
    role_arn   = aws_iam_role.firehose_role_es.arn
    index_name = "osquery_results"

    vpc_config {
      subnet_ids         = module.vpc.private_subnets
      security_group_ids = [module.vpc.default_security_group_id]
      role_arn           = aws_iam_role.firehose_role_es.arn
    }
  }
}

data "aws_iam_policy_document" "opensearch_access_policy" {
  statement {
    actions = ["es:*"]
    principals {
      identifiers = ["*"]
      type        = "*"
    }
    effect = "Allow"
    resources = [
      "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/osquery-results/",
      "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/osquery-results/*",
    ]
  }
}

resource "aws_elasticsearch_domain" "es_domain" {
  domain_name           = "osquery-results"
  elasticsearch_version = "OpenSearch_1.0"
  access_policies       = data.aws_iam_policy_document.opensearch_access_policy.json

  advanced_options = {
    "rest.action.multi.allow_explicit_index" = "true"
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 100
  }

  # cluster_config
  cluster_config {
    instance_type            = "c6g.large.elasticsearch"
    dedicated_master_type    = "c6g.large.elasticsearch"
    instance_count           = 3
    dedicated_master_count   = 0
    dedicated_master_enabled = false
    zone_awareness_enabled   = true
    zone_awareness_config {
      availability_zone_count = 3
    }


  }
  vpc_options {
    security_group_ids = [module.vpc.default_security_group_id]
    subnet_ids         = module.vpc.private_subnets
  }


}

resource "aws_iam_service_linked_role" "opensearch" {
  aws_service_name = "es.amazonaws.com"
}