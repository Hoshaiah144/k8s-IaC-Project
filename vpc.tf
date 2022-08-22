#
# Terraform will Provision the below VPC Resources
#  -- VPC
#  -- Subnets
#  -- Internet Gateway
#  -- Route Table
#

resource "aws_vpc" "k8s_projects" {
  cidr_block = "10.0.0.0/16"

  tags = tomap({
    "Name"                                      = "terraform-eks-project-node",
    "kubernetes.io/cluster/${var.cluster-name}" = "shared",
  })
}


resource "aws_subnet" "k8s_projects" {
  count = 6

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = "10.0.${count.index}.0/24"
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.k8s_projects.id

  tags = tomap({
    "Name"                                      = "terraform-eks-project-node",
    "kubernetes.io/cluster/${var.cluster-name}" = "shared",
  })
}

resource "aws_internet_gateway" "k8s_projects" {
  vpc_id = aws_vpc.k8s_projects.id

  tags = {
    Name = "terraform-eks-project"
  }
}

resource "aws_route_table" "k8s_projects" {
  vpc_id = aws_vpc.k8s_projects.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s_projects.id
  }
}

resource "aws_route_table_association" "k8s_projects" {
  count = 2

  subnet_id      = aws_subnet.k8s_projects.*.id[count.index]
  route_table_id = aws_route_table.k8s_projects.id
}