#!/bin/bash
# jenkins-setup.sh
# User data script for EC2 instance - installs and configures Jenkins

set -e

# Log everything
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=========================================="
echo "Starting Jenkins Installation"
echo "=========================================="
echo "Start Time: $(date)"
echo ""

# Update system
echo "Step 1/10: Updating system packages..."
yum update -y
echo "✅ System updated"

# Install Java (Jenkins requires Java)
echo ""
echo "Step 2/10: Installing Java..."
amazon-linux-extras install java-openjdk11 -y
java -version
echo "✅ Java installed"

# Install Jenkins
echo ""
echo "Step 3/10: Installing Jenkins..."
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
yum install jenkins -y
echo "✅ Jenkins installed"

# Install Docker
echo ""
echo "Step 4/10: Installing Docker..."
yum install docker -y
systemctl start docker
systemctl enable docker
docker --version
echo "✅ Docker installed and started"

# Add jenkins user to docker group
echo ""
echo "Step 5/10: Configuring Docker permissions..."
usermod -aG docker jenkins
usermod -aG docker ec2-user
echo "✅ Docker permissions configured"

# Install Trivy (security scanner)
echo ""
echo "Step 6/10: Installing Trivy..."
cd /tmp
wget https://github.com/aquasecurity/trivy/releases/download/v0.48.0/trivy_0.48.0_Linux-64bit.tar.gz
tar zxvf trivy_0.48.0_Linux-64bit.tar.gz
mv trivy /usr/bin/trivy
chmod +x /usr/bin/trivy
trivy --version
echo "✅ Trivy installed"

# Install AWS CLI v2
echo ""
echo "Step 7/10: Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
aws --version
echo "✅ AWS CLI v2 installed"

# Install CloudWatch agent
echo ""
echo "Step 8/10: Installing CloudWatch agent..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm
echo "✅ CloudWatch agent installed"

# Configure CloudWatch agent
echo ""
echo "Step 9/10: Configuring CloudWatch agent..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<'CWCONFIG'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/jenkins/jenkins.log",
            "log_group_name": "/aws/jenkins/application",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "Jenkins",
    "metrics_collected": {
      "disk": {
        "measurement": [{"name": "used_percent"}],
        "resources": ["*"]
      },
      "mem": {
        "measurement": [{"name": "mem_used_percent"}]
      }
    }
  }
}
CWCONFIG

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

echo "✅ CloudWatch agent configured and started"

# Start Jenkins
echo ""
echo "Step 10/10: Starting Jenkins..."
systemctl start jenkins
systemctl enable jenkins
echo "✅ Jenkins service started"

# Wait for Jenkins to initialize
echo ""
echo "Waiting for Jenkins to initialize..."
sleep 60

# Store initial admin password in Secrets Manager
echo ""
echo "Storing Jenkins password in Secrets Manager..."
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    JENKINS_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
    aws secretsmanager create-secret \
      --name devops/jenkins/initial-password \
      --secret-string "{\"password\":\"$JENKINS_PASSWORD\"}" \
      --region eu-north-1 2>&1 || echo "Secret might already exist"
    echo "✅ Jenkins password stored"
else
    echo "⚠️  Jenkins password file not found yet"
fi

# Display status
echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo "End Time: $(date)"
echo ""
echo "Installed Components:"
echo "  ✅ Java 11"
echo "  ✅ Jenkins"
echo "  ✅ Docker"
echo "  ✅ Trivy"
echo "  ✅ AWS CLI v2"
echo "  ✅ CloudWatch Agent"
echo ""
echo "Services Status:"
systemctl status jenkins --no-pager | head -3
systemctl status docker --no-pager | head -3
echo ""
echo "Access Jenkins:"
echo "  http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo ""
echo "=========================================="
