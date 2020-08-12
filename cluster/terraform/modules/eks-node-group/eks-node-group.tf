locals {
  tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
}

module "label" {
  source = "./../null-label"
  namespace = var.namespace
  stage = var.stage
  name = var.name
  delimiter = var.delimiter
  attributes = compact(concat(var.attributes, ["workers"]))
  tags = local.tags
  enabled = var.enabled
}

data "aws_iam_policy_document" "assume_role" {
  count = var.enabled ? 1 : 0

  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "external_dns_policy" {
  name        = "K8sExternalDNSPolicy"
  path        = "/"
  description = "Allows EKS nodes to modify Route53 to support ExternalDNS"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
	"route53:ListResourceRecordSets"
      ],
      "Resource": ["*"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": ["*"]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach_k8s_external_dns_iam_policy" {
  count = var.enabled ? 1 : 0
  policy_arn = aws_iam_policy.external_dns_policy.arn
  role = join("", aws_iam_role.default.*.name)
}

resource "aws_iam_role" "default" {
  count = var.enabled ? 1 : 0
  name = module.label.id
  assume_role_policy = join("", data.aws_iam_policy_document.assume_role.*.json)
  tags = module.label.tags
}

resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
  count = var.enabled ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role = join("", aws_iam_role.default.*.name)
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy" {
  count = var.enabled ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role = join("", aws_iam_role.default.*.name)
}

resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
  count = var.enabled ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role = join("", aws_iam_role.default.*.name)
}

resource "aws_iam_role_policy_attachment" "existing_policies_for_eks_workers_role" {
  count = var.enabled ? var.existing_workers_role_policy_arns_count : 0
  policy_arn = var.existing_workers_role_policy_arns[count.index]
  role = join("", aws_iam_role.default.*.name)
}

resource "aws_eks_node_group" "default" {
  count = var.enabled ? 1 : 0
  cluster_name = var.cluster_name
  node_group_name = module.label.id
  node_role_arn = join("", aws_iam_role.default.*.arn)
  subnet_ids = var.subnet_ids
  ami_type = var.ami_type
  disk_size = var.disk_size
  instance_types = var.instance_types
  labels = var.kubernetes_labels
  release_version = var.ami_release_version
  version = var.kubernetes_version

  tags = module.label.tags

  scaling_config {
    desired_size = var.desired_size
    max_size = var.max_size
    min_size = var.min_size
  }

  dynamic "remote_access" {
    for_each = var.ec2_ssh_key != null && var.ec2_ssh_key != "" ? ["true"] : []
    content {
      ec2_ssh_key = var.ec2_ssh_key
      source_security_group_ids = var.source_security_group_ids
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.attach_k8s_external_dns_iam_policy,
    aws_iam_role_policy_attachment.amazon_eks_worker_node_policy,
    aws_iam_role_policy_attachment.amazon_eks_cni_policy,
    aws_iam_role_policy_attachment.amazon_ec2_container_registry_read_only
  ]
}
