resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "eks-cicd-project-vpc"
  }
}

resource "aws_subnet" "public_1"{
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "eu-north-1a"
    tags = {
        Name = "eks-public-subnet-1"
    }
}

resource "aws_subnet" "public_2" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "eu-north-1b"
    tags = {
        Name = "eks-public-subnet-2"
    }
}

resource "aws_subnet" "private_1" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.3.0/24"
    availability_zone = "eu-north-1a"
    tags = {
        Name = "eks-private-subnet-1"
    }
}

resource "aws_subnet" "private_2" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.4.0/24"
    availability_zone = "eu-north-1b"
    tags = {
        Name = "eks-private-subnet-2"
    }
}

resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "eks-internet-gateway"
    }
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main.id
    }
    tags = {
        Name = "eks-public-routing-table"
    }
}

resource "aws_route_table_association" "public_1"{
    subnet_id = aws_subnet.public_1.id
    route_table_id = aws_route_table.public.id
}


resource "aws_route_table_association" "public_2"{
    subnet_id = aws_subnet.public_2.id
    route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
    domain = "vpc"
    tags = {
        Name = "eks-elastic-ip"
    }
}

resource "aws_nat_gateway" "main" {
    allocation_id = aws_eip.nat.id
    subnet_id = aws_subnet.public_1.id
    tags = {
        Name = "eks-NAT-gateway"
    }
    depends_on = [
        aws_internet_gateway.main
    ]
}

resource "aws_route_table" "private"{
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.main.id
    }
    tags = {
        Name = "eks-private-routing-table"
    }
}

resource "aws_route_table_association" "private_1" {
    route_table_id = aws_route_table.private.id
    subnet_id = aws_subnet.private_1.id
}

resource "aws_route_table_association" "private_2" {
    route_table_id = aws_route_table.private.id
    subnet_id = aws_subnet.private_2.id
}

resource "aws_security_group" "jenkins_sg" {
    vpc_id = aws_vpc.main.id
    description = " Security group for the Ec2 of jenkins"
    name = "jenkins-sg"
    tags = {
        Name = "jenkins-sg"
    }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
    security_group_id = aws_security_group.jenkins_sg.id
    cidr_ipv4 = "0.0.0.0/0"
    from_port = "22"
    to_port = "22"
    ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "sonarqube" {
    security_group_id = aws_security_group.jenkins_sg.id
    cidr_ipv4 = "0.0.0.0/0"
    from_port = "9000"
    to_port = "9000"
    ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "jenkins" {
    security_group_id = aws_security_group.jenkins_sg.id
    cidr_ipv4 = "0.0.0.0/0"
    from_port = "8080"
    to_port = "8080"
    ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "jenkins_all_outbound" {
    security_group_id = aws_security_group.jenkins_sg.id
    cidr_ipv4 = "0.0.0.0/0"
    ip_protocol = "-1"
}



resource "aws_instance" "jenkins" {
    ami = "ami-0fda9ae30d2185bbd"

    instance_type = "t3.small"
    subnet_id = aws_subnet.public_1.id

    vpc_security_group_ids = [
        aws_security_group.jenkins_sg.id
    ]
    associate_public_ip_address = true
    key_name = var.key_name
    iam_instance_profile = aws_iam_instance_profile.jenkins.name
    tags = {
        Name = "server"
    }
}

resource "aws_iam_role" "ec2_role_to_ecr" {
    name = "ec2-role-to-ecr"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "ec2-role-to-ecr"
  }
}

resource "aws_iam_policy" "jenkins_ecr_policy" {
  name        = "jenkins-ecr-policy"
  description = "Allow Jenkins EC2 to push images to ECR"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken"
        ]

        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:CompleteLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:PutImage",
          "ecr:BatchGetImage"
        ]

        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_to_ecr" {
  role       = aws_iam_role.ec2_role_to_ecr.name
  policy_arn = aws_iam_policy.jenkins_ecr_policy.arn
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "jenkins-ec2-profile"
  role = aws_iam_role.ec2_role_to_ecr.name
}

resource "aws_ecr_repository" "app" {
  name                 = "app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
  
  tags = {
    Name = "app"
  }
}

resource "aws_iam_role" "cluster_role" {
    name = "eks-cluster-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
    })
    
    tags = {
        Name = "eks-cluster-role"
    }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_role" {
    role = aws_iam_role.cluster_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "worker_role" {
    name = "eks-worker-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Sid    = ""
            Principal = {
            Service = "ec2.amazonaws.com"
            }
        },
        ]
    })
    tags = {
        Name = "worker-role"
    }
}

resource "aws_iam_role_policy_attachment" "worker_policy" {
    role = aws_iam_role.worker_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "CNI_policy" {
    role = aws_iam_role.worker_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "pull_image_policy" {
    role = aws_iam_role.worker_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_eks_cluster" "main" {
  name = "devops-eks-cluster"

  access_config {
    authentication_mode = "API"
  }

  role_arn = aws_iam_role.cluster_role.arn
  version  = "1.35"

  vpc_config {
    subnet_ids = [
      aws_subnet.private_1.id,
      aws_subnet.private_2.id,
    ]
  }

  # Ensure that IAM Role permissions are created before and deleted
  # after EKS Cluster handling. Otherwise, EKS will not be able to
  # properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_role,
  ]
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "devops-eks-node-group"

  node_role_arn = aws_iam_role.worker_role.arn

  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]

  instance_types = ["t3.small"]

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 2
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker_policy,
    aws_iam_role_policy_attachment.CNI_policy,
    aws_iam_role_policy_attachment.pull_image_policy
  ]

  tags = {
    Name = "eks-worker-node"
  }
}

resource "aws_eks_access_entry" "admin_user" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = "arn:aws:iam::305018987435:user/ahmmedtarek"
}

resource "aws_eks_access_policy_association" "admin_user" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_eks_access_entry.admin_user.principal_arn

  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}