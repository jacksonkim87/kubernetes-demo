module "label" {
  source = "./../null-label"
  namespace = var.namespace
  stage = var.stage
  name = var.name
  delimiter = var.delimiter
  attributes = compact(concat(var.attributes, ["cluster"]))
  tags = var.tags
  enabled = var.enabled
}

data "aws_iam_policy_document" "assume_role" {
  count = var.enabled ? 1 : 0

  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "default" {
  count = var.enabled ? 1 : 0
  name = module.label.id
  assume_role_policy = join("", data.aws_iam_policy_document.assume_role.*.json)
  tags = module.label.tags
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cluster_policy" {
  count = var.enabled ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role = join("", aws_iam_role.default.*.name)
}

resource "aws_iam_role_policy_attachment" "amazon_eks_service_policy" {
  count = var.enabled ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role = join("", aws_iam_role.default.*.name)
}

resource "aws_security_group" "default" {
  description = "Security Group for EKS cluster"
  count = var.enabled ? 1 : 0
  name = module.label.id
  vpc_id = var.vpc_id
  tags = module.label.tags
}

resource "aws_security_group_rule" "egress" {
  description = "Allow all egress traffic"
  count = var.enabled ? 1 : 0
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = join("", aws_security_group.default.*.id)
  type = "egress"
}

resource "aws_security_group_rule" "ingress_workers" {
  description = "Allow the cluster to receive communication from the worker nodes"
  count = var.enabled ? length(var.workers_security_group_ids) : 0
  from_port = 0
  to_port = 65535
  protocol = "-1"
  source_security_group_id = var.workers_security_group_ids[count.index]
  security_group_id = join("", aws_security_group.default.*.id)
  type = "ingress"
}

resource "aws_security_group_rule" "ingress_security_groups" {
  description = "Allow inbound traffic from existing Security Groups"
  count = var.enabled ? length(var.allowed_security_groups) : 0
  from_port = 0
  to_port = 65535
  protocol = "-1"
  source_security_group_id = var.allowed_security_groups[count.index]
  security_group_id = join("", aws_security_group.default.*.id)
  type = "ingress"
}

resource "aws_security_group_rule" "ingress_cidr_blocks" {
  description = "Allow inbound traffic from CIDR blocks"
  count = var.enabled && length(var.allowed_cidr_blocks) > 0 ? 1 : 0
  from_port = 0
  to_port = 65535
  protocol = "-1"
  cidr_blocks = var.allowed_cidr_blocks
  security_group_id = join("", aws_security_group.default.*.id)
  type = "ingress"
}

resource "aws_eks_cluster" "default" {
  count = var.enabled ? 1 : 0
  name = module.label.id
  tags = module.label.tags
  role_arn = join("", aws_iam_role.default.*.arn)
  version = var.kubernetes_version
  enabled_cluster_log_types = var.enabled_cluster_log_types

  vpc_config {
		security_group_ids = [join("", aws_security_group.default.*.id)]
    subnet_ids = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access = var.endpoint_public_access
  }

  depends_on = [
    aws_iam_role_policy_attachment.amazon_eks_cluster_policy,
    aws_iam_role_policy_attachment.amazon_eks_service_policy
  ]
}

resource "aws_iam_openid_connect_provider" "default" {
  count = (var.enabled && var.oidc_provider_enabled) ? 1 : 0
  url = join("", aws_eks_cluster.default.*.identity.0.oidc.0.issuer)

  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
}
