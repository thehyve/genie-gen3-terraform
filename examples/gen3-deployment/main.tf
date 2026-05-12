provider "aws" {

  region = local.aws_region

  default_tags {
    tags = local.default_tags
  }
}

data "aws_caller_identity" "current" {}

terraform {
  backend "s3" {
    bucket         = "opentofu-state-918475456291-us-east-1-an"
    key            = "gen3/terraform.tfstate"
    dynamodb_table = "opentofu-state-locks"
    encrypt        = "true"
    region         = "us-east-1"
  }
}

locals {
  # This will be the name of the VPC, and will be used to identify most resources created within the module
  vpc_name = "gen3-genie-dev"
  # The account number where the resources will be created in. This should be populated automatically through the AWS user/role you are using to run this module.
  account_number = data.aws_caller_identity.current.account_id
  # The AWS region where the resources will be created in
  aws_region = "us-east-1"
  # The namespace your gen3 deployment will use. Default is good for first time deployments.
  ## If you want another deployment in the same cluster, copy paste the gen3 module block, create a new namespace local variable or manually update the namespace within the second instance of the module.
  kubernetes_namespace = "default"
  # The availability zones where the resources will be created in. There should be 3 availability zones
  ## You can run aws ec2 describe-availability-zones --region <region> to get the list of availability zones in your region.
  availability_zones = ["us-east-1a", "us-east-1c"]
  # The hostname for your gen3 deployment. If you are creating another instance of the gen3 module set the hostname in it accordingly
  hostname = "portal.genie.aacr.org"
  # Service linked roles can only be created once per account. If you see an error that it is already created, set this to false.
  es_linked_role = true
  # Service linked role for spot instances
  spot_linked_role = true
  # The arn of the certificate in ACM
  revproxy_arn = "<Update with your ACM certificate arn>"
  # Whether or not to create users/buckets needed for useryaml gitops management.
  create_gitops_infra = true
  # The name of the S3 bucket where the user.yaml file will be stored. Notice this will be created by terraform, so you don't need to create it beforehand.
  user_yaml_bucket_name = "gen3-genie-users"
  # Your ssh key name to access the nodes in the EKS cluster
  ssh_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCXzuu5zIASCSON3ZUtwiv5BCG96f9NOW3OuZJAheshRJs2kn5RfoVGK5+kvrBNQoivE5xbDaj5dFf7LU2cKSr+gD9bIeMVv9qF5vdtpQgUeEP2E+EFg3iHS6FRR6sKzatomEzGB+q8NIZlyuyO/R0xqo+8XwIyxHyoxmM82atqbaRKz4QqNfzp6hL8ECr4outlxaUrE5djzlps63NJGXs1YGWc4ROsGUR9kbDS9KcmHI8wA8nj+eFDiSZZnINj/yHTW0iWNp0g3CicfwVVFSzNT6RuhXDd55ZnHltApcUdfFNWzOhUyxW0rxp60+kubhgyOCFjtnhkOrXirKlhx9mG+PTED8pPKkzN6dIMz1uoe67C2sljetmmKbSV4HSMug9CTSlOkwAwmqyDuTFP92FpCMG5DedoSg2zuucvl9RaADDeycEQ8uUKWlfCcwfzZ7U8iY74sjKZztez/hPoNpvET2Iy5+Fs1k2Dr3VT9MxUiSWJaFR/EFwK5gbFL5sPD1v2UGBrmPGRvoz0CuWpZh6laRkNdSPT1TT+z08a56bTH8KFpqOGTzdfbEMN1zst0xNSpPkQLZxaWdRokxwOnZdgXYx9+a4N9q7/VlfBQ6vhe89wO5qtgpRk00qiO9fs12r9Qr6YmMK+6tTQq4rxsv2kSxFCev6LlPGBhA/x/9xFKw== pnp300@pnp300-ThinkPad-X1-Carbon-Gen-11"
  # Set any tags you want to apply to all resources created by this module.
  default_tags = {
    Environment = local.vpc_name
  }


  ### Cognito setup
  deploy_cognito  = true
  user_pool_name  = "${local.vpc_name}-pool"
  app_client_name = "${local.vpc_name}-client"
  domain_prefix   = "${local.vpc_name}-auth"
  callback_urls = [
    "https://${local.hostname}/",
    "https://${local.hostname}/login/",
    "https://${local.hostname}/login/cognito/login/",
    "https://${local.hostname}/user/",
    "https://${local.hostname}/user/login/cognito/",
    "https://${local.hostname}/user/login/cognito/login/",
  ]
  logout_urls = [
    "https://${local.hostname}/",
  ]
  allowed_oauth_flows          = ["code"]
  allowed_oauth_scopes         = ["email", "openid", "phone", "profile"]
  supported_identity_providers = ["COGNITO"]
}

module "commons" {
  source = "../../tf_files/aws/commons"
  # source = "git::github.com/uc-cdis/gen3-terraform.git//tf_files/aws/commons?ref=master"

  vpc_name                     = local.vpc_name
  vpc_cidr_block               = "10.10.0.0/20"
  aws_region                   = local.aws_region
  hostname                     = local.hostname
  kube_ssh_key                 = local.ssh_key
  ami_account_id               = "amazon"
  squid_image_search_criteria  = "amzn2-ami-hvm-*-x86_64-gp2"
  ha-squid_instance_drive_size = 30
  ha_squid_single_instance     = true
  deploy_ha_squid              = true
  deploy_sheepdog_db           = false
  deploy_fence_db              = false
  deploy_indexd_db             = false
  network_expansion            = true
  users_policy                 = "dev"
  availability_zones           = local.availability_zones
  es_version                   = "7.10"
  es_linked_role               = local.es_linked_role
  deploy_aurora                = true
  deploy_rds                   = false
  use_asg                      = false
  use_karpenter                = true
  karpenter_version            = "1.12.0" # Needed for K8S 1.35
  deploy_karpenter_in_k8s      = true
  send_logs_to_csoc            = false
  secrets_manager_enabled      = true
  force_delete_bucket          = true
  enable_vpc_endpoints         = false
  cluster_engine_version       = "13"
  eks_version                  = "1.35"
}

module "gen3" {
  source                  = "../../tf_files/gen3"
  vpc_name                = local.vpc_name
  aurora_username         = module.commons.aurora_cluster_master_username
  aurora_password         = module.commons.aurora_cluster_master_password
  aurora_hostname         = module.commons.aurora_cluster_writer_endpoint
  dictionary_url          = "https://s3.amazonaws.com/dictionary-artifacts/datadictionary/develop/schema.json"
  es_endpoint             = module.commons.es_endpoint
  hostname                = local.hostname
  cluster_endpoint        = module.commons.eks_cluster_endpoint
  cluster_ca_cert         = module.commons.eks_cluster_ca_cert
  cluster_name            = module.commons.eks_cluster_name
  oidc_provider_arn       = module.commons.eks_oidc_arn
  fence_access_key        = module.commons.fence-bot_user_id
  fence_secret_key        = module.commons.fence-bot_user_secret
  upload_bucket           = module.commons.data-bucket_name
  revproxy_arn            = local.revproxy_arn
  useryaml_s3_path        = "s3://${local.user_yaml_bucket_name}/dev/user.yaml"
  deploy_external_secrets = true
  deploy_gen3             = false
  create_dbs              = false # Do not use local executor
  create_dbs_with_job     = true  # Use Kubernetes job to provision the database
  cognito_discovery_url   = "https://${aws_cognito_user_pool.cognito_pool[0].endpoint}/.well-known/openid-configuration"
  cognito_client_id       = aws_cognito_user_pool_client.cognito_client[0].id
  cognito_client_secret   = aws_cognito_user_pool_client.cognito_client[0].client_secret

  providers = {
    helm       = helm
    kubernetes = kubernetes
  }

  depends_on = [
    module.commons,
  ]
}


resource "aws_iam_user" "gitops_user" {
  count = local.create_gitops_infra ? 1 : 0
  name  = "gitops-user"
}

resource "aws_iam_user_policy" "gitops_s3_policy" {
  count = local.create_gitops_infra ? 1 : 0
  name  = "gitops-user-s3-access"
  user  = aws_iam_user.gitops_user[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::${local.user_yaml_bucket_name}"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${local.user_yaml_bucket_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_access_key" "gitops_key" {
  count = local.create_gitops_infra ? 1 : 0
  user  = aws_iam_user.gitops_user[0].name
}

resource "aws_s3_bucket" "users_bucket" {
  count         = local.create_gitops_infra ? 1 : 0
  bucket        = local.user_yaml_bucket_name
  force_destroy = true
  tags = {
    Name        = "user-yaml-bucket"
    Environment = local.vpc_name
  }
}
