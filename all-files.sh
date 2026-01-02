#!/bin/bash
# setup-all.sh
# Master setup script that runs all infrastructure setup scripts

set -e

echo "========================================"
echo "Secure DevOps Pipeline - Complete Setup"
echo "========================================"
echo ""
echo "This will create all AWS infrastructure:"
echo "  ✅ VPC and networking"
echo "  ✅ Security groups"
echo "  ✅ IAM roles and policies"
echo "  ✅ Secrets in Secrets Manager"
echo "  ✅ CloudTrail for auditing"
echo "  ✅ Jenkins EC2 instance"
echo ""
echo "Estimated time: 15 minutes"
echo "Region: eu-north-1"
echo ""
echo "⚠️  This will create AWS resources that incur costs"
echo "   (~$35-40/month if running 24/7)"
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Setup cancelled"
    exit 0
fi

# Check if AWS CLI is configured
echo ""
echo "Checking AWS CLI configuration..."
if ! aws sts get-caller-identity &>/dev/null; then
    echo "❌ Error: AWS CLI is not configured"
    echo ""
    echo "Please run: aws configure"
    echo "And enter your AWS credentials"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✅ AWS CLI configured"
echo "   Account: $ACCOUNT_ID"

# Create outputs directory
mkdir -p ../outputs

# Run setup scripts in order
echo ""
echo "========================================"
echo "Starting Setup Process"
echo "========================================"

# Step 1: VPC
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1/6: Setting up VPC and Networking"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./01-setup-vpc.sh
echo ""
read -p "Press Enter to continue to Step 2..."

# Step 2: Security Groups
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2/6: Setting up Security Groups"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./02-setup-security-groups.sh
echo ""
read -p "Press Enter to continue to Step 3..."

# Step 3: IAM
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3/6: Setting up IAM Roles"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./03-setup-iam.sh
echo ""
read -p "Press Enter to continue to Step 4..."

# Step 4: Secrets Manager
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4/6: Setting up Secrets Manager"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./04-setup-secrets.sh
echo ""
read -p "Press Enter to continue to Step 5..."

# Step 5: CloudTrail
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5/6: Setting up CloudTrail"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./05-setup-cloudtrail.sh
echo ""
read -p "Press Enter to continue to Step 6..."

# Step 6: Launch Jenkins
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 6/6: Launching Jenkins Server"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./06-launch-jenkins.sh

# Load final resource IDs
source ../outputs/resource-ids.txt

# Final summary
echo ""
echo ""
echo "========================================"
echo "✅ Setup Complete!"
echo "========================================"
echo ""
echo "📋 Resource Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "VPC ID: $VPC_ID"
echo "Subnet ID: $SUBNET_ID"
echo "Security Group: $SG_ID"
echo "IAM Role: JenkinsServerRole"
echo "CloudTrail: devops-security-trail"
echo "EC2 Instance: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo ""
echo "📝 All resource IDs saved to:"
echo "   ../outputs/resource-ids.txt"
echo ""
echo "🔑 SSH Key saved to:"
echo "   ../outputs/jenkins-key.pem"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏱️  Jenkins Installation Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Jenkins is being installed automatically."
echo "This process takes 5-10 minutes."
echo ""
echo "To monitor progress:"
echo "  ssh -i ../outputs/jenkins-key.pem ec2-user@$PUBLIC_IP"
echo "  tail -f /var/log/user-data.log"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Next Steps (After 10 minutes)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Get Jenkins URL:"
echo "   ./get-jenkins-url.sh"
echo ""
echo "2. Get Jenkins password:"
echo "   ./get-jenkins-password.sh"
echo ""
echo "3. Access Jenkins:"
echo "   http://$PUBLIC_IP:8080"
echo ""
echo "4. Follow setup wizard in browser"
echo ""
echo "5. Create your first pipeline"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💰 Cost Reminder"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Running costs: ~$1/day (~$35-40/month)"
echo ""
echo "To stop charges:"
echo "  - Stop instance: aws ec2 stop-instances --instance-ids $INSTANCE_ID"
echo "  - Delete all: ./cleanup.sh"
echo ""
echo "========================================"
echo ""
echo "🎉 Your DevOps pipeline is ready!"
echo ""
