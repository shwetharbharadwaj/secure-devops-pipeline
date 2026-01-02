#!/bin/bash
# get-jenkins-password.sh
# Retrieves Jenkins initial admin password

set -e

echo "=========================================="
echo "Retrieving Jenkins Initial Password"
echo "=========================================="
echo ""

# Load resource IDs
source ../outputs/resource-ids.txt 2>/dev/null || source outputs/resource-ids.txt 2>/dev/null

AWS_REGION=${AWS_REGION:-eu-north-1}

# Try to get password from Secrets Manager
echo "Checking AWS Secrets Manager..."
PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id devops/jenkins/initial-password \
  --region $AWS_REGION \
  --query SecretString \
  --output text 2>/dev/null | grep -o '"password":"[^"]*"' | cut -d'"' -f4)

if [ -n "$PASSWORD" ]; then
    echo "✅ Password retrieved from Secrets Manager"
    echo ""
    echo "=========================================="
    echo "Jenkins Initial Admin Password:"
    echo ""
    echo "  $PASSWORD"
    echo ""
    echo "=========================================="
    echo ""
    echo "Copy this password to login to Jenkins"
    exit 0
fi

# If not in Secrets Manager, try SSH to instance
echo "⚠️  Password not found in Secrets Manager"
echo ""
echo "Trying to retrieve from Jenkins server..."

if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP=$(aws ec2 describe-instances \
      --filters "Name=tag:Name,Values=Jenkins-Server" "Name=instance-state-name,Values=running" \
      --region $AWS_REGION \
      --query 'Reservations[0].Instances[0].PublicIpAddress' \
      --output text)
fi

if [ "$PUBLIC_IP" == "None" ] || [ -z "$PUBLIC_IP" ]; then
    echo "❌ Error: Cannot find Jenkins instance"
    exit 1
fi

# Check if key exists
KEY_PATH="../outputs/jenkins-key.pem"
if [ ! -f "$KEY_PATH" ]; then
    KEY_PATH="outputs/jenkins-key.pem"
fi

if [ ! -f "$KEY_PATH" ]; then
    echo "❌ Error: SSH key not found"
    echo "Expected location: outputs/jenkins-key.pem"
    exit 1
fi

echo "Connecting to Jenkins server..."
PASSWORD=$(ssh -i $KEY_PATH \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    ec2-user@$PUBLIC_IP \
    "sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null" || echo "")

if [ -n "$PASSWORD" ]; then
    echo "✅ Password retrieved from server"
    echo ""
    echo "=========================================="
    echo "Jenkins Initial Admin Password:"
    echo ""
    echo "  $PASSWORD"
    echo ""
    echo "=========================================="
else
    echo "❌ Could not retrieve password"
    echo ""
    echo "Possible reasons:"
    echo "1. Jenkins is still installing (wait 5-10 minutes)"
    echo "2. Installation failed (check logs)"
    echo ""
    echo "To check installation status:"
    echo "  ssh -i $KEY_PATH ec2-user@$PUBLIC_IP"
    echo "  tail -f /var/log/user-data.log"
    exit 1
fi
