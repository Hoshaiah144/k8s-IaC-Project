#
# Terraform Provisions EKS Cluster Resources
#  -- IAM Role to allow EKS service to manage other AWS services
#  -- EC2 Security Group to allow networking traffic with EKS cluster
#  -- EKS Cluster
#

resource "aws_iam_role" "k8s_projects-cluster" {
  name = "terraform-eks-k8s_projects-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "k8s_projects-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.k8s_projects-cluster.name
}

resource "aws_iam_role_policy_attachment" "k8s_projects-cluster-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.k8s_projects-cluster.name
}

resource "aws_security_group" "k8s_projects-cluster" {
  name        = "terraform-eks-projects-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.k8s_projects.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-eks-k8s_projects"
  }
}

resource "aws_security_group_rule" "k8s_projects-cluster-ingress-workstation-https" {
  cidr_blocks       = [local.workstation-external-cidr]
  description       = "Allow workstation to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.k8s_projects-cluster.id
  to_port           = 443
  type              = "ingress"
}

resource "aws_eks_cluster" "k8s_projects" {
  name     = var.cluster-name
  role_arn = aws_iam_role.k8s_projects-cluster.arn

  vpc_config {
    security_group_ids = [aws_security_group.k8s_projects-cluster.id]
    subnet_ids         = aws_subnet.k8s_projects[*].id
  }

  depends_on = [
    aws_iam_role_policy_attachment.k8s_projects-cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.k8s_projects-cluster-AmazonEKSVPCResourceController,
  ]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.k8s_projects.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.k8s_projects.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.k8s_projects.token
  load_config_file       = false
  # version                = "~> 1.21.9"
}

resource "kubernetes_deployment" "example" {
  metadata {
    name = "terraform-example"
    labels = {
      test = "MyExampleApp"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        test = "MyExampleApp"
      }
    }

    template {
      metadata {
        labels = {
          test = "MyExampleApp"
        }
      }

      spec {
        container {
          image = "nginx:1.7.8"
          name  = "example"

          resources {
            limits {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "example" {
  metadata {
    name = "terraform-example"
  }
  spec {
    selector = {
      test = "MyExampleApp"
    }
    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}