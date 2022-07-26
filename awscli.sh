#!/bin/bash


AWS_REGION="us-east-1"
VPC_NAME="My VPC"
VPC_CIDR="10.0.0.0/16"
SUBNET_PUBLIC_CIDR="10.0.1.0/24"
SUBNET_PUBLIC_AZ="us-east-1a"
SUBNET_PUBLIC_NAME="public-subnet"
SUBNET_PRIVATE_CIDR="10.0.2.0/24"
SUBNET_PRIVATE_AZ="us-east-1b"
SUBNET_PRIVATE_NAME="private-subnet"
PUBLIC_KP="testjava"
PRIVATE_KP="testjava"
AMI_ID="ami-052efd3df9dad4825"

aws ec2 import-key-pair --key-name "testjava" --public-key-material fileb://testjava.pub

# Create VPC
echo "Creating VPC in preferred region..."
VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --query 'Vpc.{VpcId:VpcId}' --output text --region $AWS_REGION)
echo "  VPC ID '$VPC_ID' CREATED in '$AWS_REGION' region."

# Add Name tag to VPC
aws ec2 create-tags --resources $VPC_ID --tags "Key=Name,Value=$VPC_NAME" --region $AWS_REGION
echo "  VPC ID '$VPC_ID' NAMED as '$VPC_NAME'."

# Create Public Subnet
echo "Creating Public Subnet..."
SUBNET_PUBLIC_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_PUBLIC_CIDR --availability-zone $SUBNET_PUBLIC_AZ --query 'Subnet.{SubnetId:SubnetId}' --output text --region $AWS_REGION)
echo "  Subnet ID '$SUBNET_PUBLIC_ID' CREATED in '$SUBNET_PUBLIC_AZ'" "Availability Zone."

# Add Name tag to Public Subnet
aws ec2 create-tags --resources $SUBNET_PUBLIC_ID --tags "Key=Name,Value=$SUBNET_PUBLIC_NAME" --region $AWS_REGION
echo "  Subnet ID '$SUBNET_PUBLIC_ID' NAMED as '$SUBNET_PUBLIC_NAME'."

# Create Private Subnet
echo "Creating Private Subnet..."
SUBNET_PRIVATE_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_PRIVATE_CIDR --availability-zone $SUBNET_PRIVATE_AZ --query 'Subnet.{SubnetId:SubnetId}' --output text --region $AWS_REGION)
echo "  Subnet ID '$SUBNET_PRIVATE_ID' CREATED in '$SUBNET_PRIVATE_AZ'" \
  "Availability Zone."

# Add Name tag to Private Subnet
aws ec2 create-tags --resources $SUBNET_PRIVATE_ID --tags "Key=Name,Value=$SUBNET_PRIVATE_NAME" --region $AWS_REGION
echo "  Subnet ID '$SUBNET_PRIVATE_ID' NAMED as '$SUBNET_PRIVATE_NAME'."

# Create Internet gateway
echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' --output text --region $AWS_REGION)
echo "  Internet Gateway ID '$IGW_ID' CREATED."

# Attach Internet gateway to your VPC
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region $AWS_REGION
echo "  Internet Gateway ID '$IGW_ID' ATTACHED to VPC ID '$VPC_ID'."

# Create Route Table
echo "Creating Route Table..."
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.{RouteTableId:RouteTableId}' --output text --region $AWS_REGION)
echo "  Route Table ID '$ROUTE_TABLE_ID' CREATED."

# Create route to Internet Gateway
RESULT=$(aws ec2 create-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $AWS_REGION)
echo "  Route to '0.0.0.0/0' via Internet Gateway ID '$IGW_ID' ADDED to" \
  "Route Table ID '$ROUTE_TABLE_ID'."

# Associate Public Subnet with Route Table
RESULT=$(aws ec2 associate-route-table  --subnet-id $SUBNET_PUBLIC_ID --route-table-id $ROUTE_TABLE_ID --region $AWS_REGION)
echo "  Public Subnet ID '$SUBNET_PUBLIC_ID' ASSOCIATED with Route Table ID" \
  "'$ROUTE_TABLE_ID'."

# Enable Auto-assign Public IP on Public Subnet
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_PUBLIC_ID --map-public-ip-on-launch --region $AWS_REGION
echo "  'Auto-assign Public IP' ENABLED on Public Subnet ID" \
  "'$SUBNET_PUBLIC_ID'."

# Allocate Elastic IP Address for NAT Gateway
echo "Creating NAT Gateway..."
EIP_ALLOC_ID=$(aws ec2 allocate-address --domain vpc --query '{AllocationId:AllocationId}' --output text --region $AWS_REGION)
echo "  Elastic IP address ID '$EIP_ALLOC_ID' ALLOCATED."


# Create NAT Gateway
NAT_GW_ID=$(aws ec2 create-nat-gateway --subnet-id $SUBNET_PUBLIC_ID --allocation-id $EIP_ALLOC_ID --query 'NatGateway.{NatGatewayId:NatGatewayId}' --output text --region $AWS_REGION)
echo " NAT Gateway ID '$NAT_GW_ID' CREATED. "

sleep 1m

# Create Route Table
echo "Creating Route Table..."
ROUTE_TABLE_ID_2=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.{RouteTableId:RouteTableId}' --output text --region $AWS_REGION)
echo "  Route Table ID 2 '$ROUTE_TABLE_ID_2' CREATED."

# Associate Private Subnet with Route Table
RESULT=$(aws ec2 associate-route-table  --subnet-id $SUBNET_PRIVATE_ID --route-table-id $ROUTE_TABLE_ID_2 --region $AWS_REGION)
echo "  Public Subnet ID '$SUBNET_PRIVATE_ID' ASSOCIATED with Route Table ID 2" \
  "'$ROUTE_TABLE_ID_2'."


# Create route to NAT Gateway
RESULT=$(aws ec2 create-route --route-table-id $ROUTE_TABLE_ID_2 --destination-cidr-block 0.0.0.0/0 --gateway-id $NAT_GW_ID --region $AWS_REGION)
echo "  Route to '0.0.0.0/0' via Internet Gateway ID '$NAT_GW_ID' ADDED to" \
  "Route Table ID '$ROUTE_TABLE_ID_2'."

#creating security-group
echo "creating SG in preferred region..."
SG_ID=$(aws ec2 create-security-group --group-name MySecurityGroup --description "My security group" --vpc-id $VPC_ID --output text --region $AWS_REGION)
echo "SG ID '$SG_ID' CREATED in '$AWS_REGION'."

#authorize security-group
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 202.89.73.81/32

aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 8080 --cidr 0.0.0.0/0

# Create key-pair for private subnet
#aws ec2 create-key-pair --key-name $PRIVATE_KP --query 'KeyMaterial' --output text > $PRIVATE_KP.pem

#creating ec2 in private-subnet
INSTANCE_ID_2=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type t2.micro --key-name $PRIVATE_KP --security-group-ids $SG_ID --subnet-id $SUBNET_PRIVATE_ID --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MyPrivateInstance}]' --user-data file://docker.sh --region $AWS_REGION)
echo "INSTANCE ID 2 '$INSTANCE_ID_2' CREATED"

sleep 1m

# Create key-pair for public subnet
#aws ec2 create-key-pair --key-name $PUBLIC_KP --query 'KeyMaterial' --output text > $PUBLIC_KP.pem

#creating ec2 in public-subnet
INSTANCE_ID_1=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type t2.micro --key-name $PUBLIC_KP --security-group-ids $SG_ID --subnet-id $SUBNET_PUBLIC_ID --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MyPublicInstance}]' --user-data file://docker.sh --region $AWS_REGION)
echo "INSTANCE ID 1 '$INSTANCE_ID_1' CREATED"
