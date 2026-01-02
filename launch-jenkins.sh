#!/bin/bash
# 06-launch-jenkins.sh
# Launches EC2 instance with Jenkins

set -e

echo "=========================================="
echo "Launching Jenkins EC2 Instance"
echo "=========================================="

# Load resource IDs
source ../outputs/resource-ids.txt

echo "Region: $AWS_REGION"
echo "VPC: $VPC_ID"
echo "Subnet: $SUBNET_ID"
echo "Security Group: $SG_ID"
echo ""

# Create SSH Key Pair
echo "Creating SSH key pair..."
aws ec2 create-key-pair \
  --key-name jenkins-key \
  --region $AWS_REGION \
  --query 'KeyMaterial' \
  --output text > ../outputs/jenkins-key.pem

chmod 400 ../outputs/jenkins-key.pem

echo "✅ SSH key pair created and saved to ../outputs/jenkins-key.pem"

# Get Latest Amazon Linux 2 AMI
echo ""
echo "Finding latest Amazon Linux 2 AMI..."
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
  --region $AWS_REGION \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text)

echo "✅ Using AMI: $AMI_ID"

# Verify user-data script exists
if [ ! -f "../user-data/jenkins-setup.sh" ]; then
    echo "❌ Error: User-data script not found!"
    echo "Expected: ../user-data/jenkins-setup.sh"
    exit 1
fi

# Launch EC2 Instance
echo ""
echo "Launching EC2 instance..."
echo "This will take a few minutes..."

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.medium \
  --key-name jenkins-key \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET_ID \
  --iam-instance-profile Name=JenkinsInstanceProfile \
  --user-data file://../user-data/jenkins-setup.sh \
  --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":30,"VolumeType":"gp3"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Jenkins-Server},{Key=Project,Value=SecureDevOpsPipeline},{Key=Environment,Value=Production}]' \
  --region $AWS_REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "✅ EC2 instance launched: $INSTANCE_ID"

# Wait for instance to be running
echo ""
echo "Waiting for instance to be running..."
aws ec2 wait instance-running \
  --instance-ids $INSTANCE_ID \
  --region $AWS_REGION

echo "✅ Instance is running"

# Get Public IP
echo ""
echo "Getting public IP address..."
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --region $AWS_REGION \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "✅ Public IP: $PUBLIC_IP"

# Save instance information
echo ""
echo "Saving instance information..."
cat >> ../outputs/resource-ids.txt <<EOF
INSTANCE_ID=$INSTANCE_ID
PUBLIC_IP=$PUBLIC_IP
AMI_ID=$AMI_ID
KEY_NAME=jenkins-key
EOF

echo "✅ Instance information saved"

# Display summary
echo ""
echo "=========================================="
echo "Jenkins Instance Launched Successfully!"
echo "=========================================="
echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo "Instance Type: t3.medium"
echo "SSH Key: ../outputs/jenkins-key.pem"
echo ""
echo "⏱️  Installation Progress:"
echo "Jenkins is being installed automatically."
echo "This process takes 5-10 minutes."
echo ""
echo "To monitor installation progress:"
echo "  ssh -i ../outputs/jenkins-key.pem ec2-user@$PUBLIC_IP"
echo "  tail -f /var/log/user-data.log"
echo ""
echo "Next Steps:"
echo "1. Wait 10 minutes for installation"
echo "2. Get Jenkins password:"
echo "   ./get-jenkins-password.sh"
echo "3. Access Jenkins:"
echo "   http://$PUBLIC_IP:8080"
echo ""
echo "=========================================="
