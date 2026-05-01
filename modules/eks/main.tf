#Custom EKS Module

#KMS Key for EKS Secrets Encryption
resource "aws_kms_key" "eks_secrets_encryption" {
  description             = "KMS Key for EKS cluster ${var.cluster_name}Encryption"
  deletion_window_in_days = 7
  enable_key_rotation = true

  tags = merge(
    var.tags,
    {
      "Name" = "${var.cluster_name}-eks-key"
    }
  )
}

resource "aws_kms_alias" "eks" {
  name = "alias/${var.cluster_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

#Cloudwatch Log Group for EKS Cluster
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7

  tags = var.tags
}

#Cluster security group
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-eks-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = var.vpc_id

   egress{
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
   }

  tags = merge(
    var.tags,
    {
      "Name" = "${var.cluster_name}-eks-cluster-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

#Node group security group
resource "aws_security_group" "node" {
    name        = "${var.cluster_name}-eks-node-sg"
    description = "Security group for EKS cluster nodes"
    vpc_id      = var.vpc_id
    
     egress{
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        description = "Allow all outbound traffic"
     }

     tags = merge(
        var.tags,
        {
          Name = "${var.cluster_name}-eks-node-sg"
          "kubernetes.io/cluster/${var.cluster_name}" = "owned"
        }
      )

      lifecycle {
        create_before_destroy = true
      }
}

#Allow nodes to communicate with cluster API
resource "aws_security_group_rule" "node_to_cluster" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
  description              = "Allow nodes to communicate with cluster control API"
}

#Allow cluster to communicate with nodes
resource "aws_security_group_rule" "cluster_to_node" {
    type                     = "egress"
    from_port                = 1025
    to_port                  = 65535
    protocol                 = "tcp"
    security_group_id        = aws_security_group.node.id
    source_security_group_id = aws_security_group.cluster.id
    description              = "Allow cluster control plane to communicate with nodes"
}

#Allow nodes to communicate with each other
resource "aws_security_group_rule" "node_to_node" {
    type                     = "ingress"
    from_port                = 0
    to_port                  = 65535
    protocol                 = "-1"
    self                     = true
    security_group_id        = aws_security_group.node.id
    description              = "Allow nodes to communicate with each other"
}

#EKS cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version = var.kubernetes_version
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids         = var.subnet_ids
    endpoint_public_access = var.endpoint_public_access
    endpoint_private_access = var.endpoint_private_access
    public_access_cidrs = var.public_access_cidrs
    security_group_ids = [aws_security_group.cluster.id]
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks.arn
    }
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
    
  depends_on = [ aws_cloudwatch_log_group.eks_cluster ]

  tags = merge(
    var.tags,
    {
      "Name" = "${var.cluster_name}-eks-cluster"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}


#OIDC provider for IRSA (IAM Roles for Service Accounts)
data "tls_certificate" "cluster" {
  count = var.enable_irsa ? 1 : 0
  url   = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  count = var.enable_irsa ? 1 : 0
  url   = aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster[0].certificates[0].sha1_fingerprint]
  
  tags = merge(
    var.tags,
    {
      "Name" = "${var.cluster_name}-eks-oidc-provider"
    }
  )
}

#EKS Addons
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"
  addon_version = var.coredns_version != "" ? var.coredns_version : null
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  
  depends_on = [ aws_eks_node_group.main ]

  tags = var.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"
  addon_version = var.kube_proxy_version != "" ? var.kube_proxy_version : null
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags
  
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
  addon_version = var.vpc_cni_version != "" ? var.vpc_cni_version : null
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags
  
}

#Launch template for EKS node group
resource "aws_launch_template" "eks_node_group" {
    for_each = var.node_groups
    name_prefix   = "${var.cluster_name}-${each.key}-node-group-"   
    description = "EKS Node Group ${var.cluster_name} ${each.key} Launch Template"

    block_device_mappings {
      device_name = "/dev/xvda"

      ebs {
        volume_size = lookup(each.value, "disk_size", 20)
        volume_type = "gp3"
        delete_on_termination = true
        iops = 3000
        throughput = 125
        encrypted = true
        }
    }

    metadata_options {
      http_endpoint = "enabled"
      http_tokens = "required"
      http_put_response_hop_limit = 2
      instance_metadata_tags = "enabled"
    }

    monitoring {
      enabled = true
    }

    network_interfaces {
      associate_public_ip_address = false
      delete_on_termination = true
      security_groups = [aws_security_group.node.id]
    }

    tag_specifications {
      resource_type = "instance"

      tags = merge(
        var.tags,
        {
          Name = "${var.cluster_name}-${each.key}-node-group"
        }
      )
    }
    lifecycle {
      create_before_destroy = true
    }

    tags = var.tags
}

#EKS Node Groups
resource "aws_eks_node_group" "main" {
    for_each = var.node_groups

    cluster_name = aws_eks_cluster.main.name
    node_group_name = each.key
    node_role_arn = var.node_role_arn
    subnet_ids = var.subnet_ids
    version = var.kubernetes_version

    scaling_config {
        desired_size = each.value.desired_size
        max_size     = each.value.max_size
        min_size     = each.value.min_size
    }

    instance_types = each.value.instance_types
    capacity_type = lookup(each.value, "capacity_type", "ON_DEMAND")

    labels = lookup(each.value, "labels", {})

    dynamic "taint" {
      for_each = coalesce(lookup(each.value, "taints", null), [])
      content {
        key = taint.value.key
        value = taint.value.value
        effect = taint.value.effect
      }
    }

    launch_template {
        id      = aws_launch_template.eks_node_group[each.key].id
        version = aws_launch_template.eks_node_group[each.key].latest_version
    }
    tags = merge(
        var.tags,
        lookup(each.value, "tags", {})
    )

    depends_on = [ 
        aws_eks_addon.vpc_cni,
        aws_eks_addon.kube_proxy
     ]

    lifecycle {
      ignore_changes = [ scaling_config[0].desired_size ]
    }
}