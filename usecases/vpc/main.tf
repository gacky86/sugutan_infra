data "aws_availability_zones" "current" {}

# まずはterraform repositoryから貼り付け。その後必要な箇所を編集
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.9.0" #追加

  # 以下の記述は、terraform residtoryにあるinputパラメータの内、デフォルトとは違う値を設定したいもの、
  # 子モジュールへの入力値によって挙動を変化させたいパラメータを記述している

  name = "${var.stage}-vpc-tf" #編集
  cidr = var.vpc_cidr #編集

  azs             = slice(data.aws_availability_zones.current.names, 0, 3) #編集
  # サブネットの設定：パブリック、プライベート(NAT Gatewayなし), プライベート(NAT Gatewayあり),
  # 引数がなければ作成されない
  # CIDRブロックの設定：cidrsubnet関数により、var.vpc_cidrを4分割して各サブネットに分配し、さらに各サブネット内で4分割してAZごとに割り当てる
  public_subnets  = [
    cidrsubnet(var.vpc_cidr, 4, 0),
    cidrsubnet(var.vpc_cidr, 4, 1),
  ] #編集
  intra_subnets  = [
    cidrsubnet(var.vpc_cidr, 4, 4),
    cidrsubnet(var.vpc_cidr, 4, 5)
  ] #追加
  private_subnets = var.enable_nat_gateway ? [
    cidrsubnet(var.vpc_cidr, 4, 8),
    cidrsubnet(var.vpc_cidr, 4, 9)
  ] : [] #編集

  enable_nat_gateway = var.enable_nat_gateway #編集
  # single_nat_gateway：VPCに1つだけのNAT Gatewayとし、AZ間でそれを共有する
  single_nat_gateway = (
    var.enable_nat_gateway
    ? (var.one_nat_gateway_per_az ? false : true)
    : false
  ) # 追加
  # AZごとにNAT Gatewayを作成する
  one_nat_gateway_per_az = (
    var.enable_nat_gateway
    ? var.one_nat_gateway_per_az
    : false
  ) # 追加

  manage_default_security_group = true # 追加
  default_security_group_ingress = [] # 追加
  default_security_group_egress = [] # 追加

  # 削除
  # enable_vpn_gateway = true

  # 削除
  # tags = {
  #   Terraform = "true"
  #   Environment = "dev"
  # }
}
