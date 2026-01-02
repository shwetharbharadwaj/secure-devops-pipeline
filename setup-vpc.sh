#!/bin/bash
# 01-setup-vpc.sh
# Creates VPC, subnet, internet gateway, and route tables

set -e

echo "=========================================="
echo "Setting up VPC and Networking"
echo "=========================================="

# Set region
export AWS_REGION="eu-north-1"

echo "Region: $AWS_REGION"
echo ""

# Create VPC
echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --region $AWS_REGION \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=secure-devops-vpc}]' \
  --query 'Vpc.VpcId' \
  --output text)

echo "✅ VPC Created: $VPC_ID"

# Wait for VPC to be available
aws ec2 wait vpc-available --vpc-ids $VPC_ID --region $AWS_REGION

# Create Subnet
echo ""
echo "Creating subnet..."
SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone ${AWS_REGION}a \
  --region $AWS_REGION \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=jenkins-subnet}]' \
  --query 'Subnet.SubnetId' \
  --output text)

echo "✅ Subnet Created: $SUBNET_ID"

# Enable auto-assign public IP
aws ec2 modify-subnet-attribute \
  --subnet-id $SUBNET_ID \
  --map-public-ip-on-launch \
  --region $AWS_REGION

echo "✅ Auto-assign public IP enabled"

# Create Internet Gateway
echo ""
echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --region $AWS_REGION \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=devops-igw}]' \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

echo "✅ Internet Gateway Created: $IGW_ID"

# Attach Internet Gateway to VPC
echo ""
echo "Attaching Internet Gateway to VPC..."
aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID \
  --region $AWS_REGION

echo "✅ Internet Gateway attached"

# Create Route Table
echo ""
echo "Creating Route Table..."
RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --region $AWS_REGION \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=public-rt}]' \
  --query 'RouteTable.RouteTableId' \
  --output text)

echo "✅ Route Table Created: $RT_ID"

# Add Internet Route
echo ""
echo "Adding internet route..."
aws ec2 create-route \
  --route-table-id $RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID \
  --region $AWS_REGION

echo "✅ Internet route added"

# Associate Route Table with Subnet
echo ""
echo "Associating route table with subnet..."
ASSOC_ID=$(aws ec2 associate-route-table \
  --subnet-id $SUBNET_ID \
  --route-table-id $RT_ID \
  --region $AWS_REGION \
  --query 'AssociationId' \
  --output text)

echo "✅ Route table associated: $ASSOC_ID"

# Save IDs to file
echo ""
echo "Saving resource IDs..."
mkdir -p ../outputs
cat > ../outputs/resource-ids.txt <<EOF
VPC_ID=$VPC_ID
SUBNET_ID=$SUBNET_ID
IGW_ID=$IGW_ID
RT_ID=$RT_ID
ASSOC_ID=$ASSOC_ID
AWS_REGION=$AWS_REGION
EOF

echo "✅ Resource IDs saved to ../outputs/resource-ids.txt"

# Display summary
echo ""
echo "=========================================="
echo "VPC Setup Complete!"
echo "=========================================="
echo "VPC ID: $VPC_ID"
echo "Subnet ID: $SUBNET_ID"
echo "Internet Gateway ID: $IGW_ID"
echo "Route Table ID: $RT_ID"
echo "Region: $AWS_REGION"
echo "=========================================="
