#!/bin/bash
# Everything SLOW and STATIC lives here — runs once at AMI bake time.
set -euo pipefail
exec > >(tee /var/log/packer-build.log) 2>&1
echo "=== PACKER BAKE STARTING: $(date) ==="

export DEBIAN_FRONTEND=noninteractive

# 1. Base packages (Removed 'upgrade' to prevent interactive UI prompts from breaking the build)
apt-get update -y
apt-get install -y ca-certificates curl fontconfig openjdk-21-jre unzip wget tar jq gnupg lsb-release

# 2. Repo signing keys (Using .asc directly to avoid GPG permission bugs)
mkdir -p /usr/share/keyrings /etc/apt/sources.list.d

# Jenkins (Updated to the new 2026 key)
wget -q -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
chmod a+r /usr/share/keyrings/jenkins-keyring.asc
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list

# Docker
wget -q -O /usr/share/keyrings/docker.asc https://download.docker.com/linux/ubuntu/gpg
chmod a+r /usr/share/keyrings/docker.asc
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

# Trivy
wget -q -O /usr/share/keyrings/trivy-keyring.asc https://aquasecurity.github.io/trivy-repo/deb/public.key
chmod a+r /usr/share/keyrings/trivy-keyring.asc
echo "deb [signed-by=/usr/share/keyrings/trivy-keyring.asc] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -cs) main" > /etc/apt/sources.list.d/trivy.list

# 3. Install all heavy packages
apt-get update -y
apt-get install -y jenkins docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin trivy

# Stop Jenkins NOW — user_data will configure JENKINS_HOME before first start
systemctl stop jenkins || true
systemctl enable jenkins docker

# Add users to docker group
usermod -aG docker ubuntu
usermod -aG docker jenkins


# Install Terraform
TERRAFORM_VERSION="1.9.8"
curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -o /tmp/terraform.zip
unzip /tmp/terraform.zip -d /usr/local/bin/
chmod +x /usr/local/bin/terraform
terraform version

# 4. kubectl
curl -fsSL "https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl" -o /tmp/kubectl
install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
rm -f /tmp/kubectl

# 5. eksctl
curl -fsSL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | tar -xz -C /tmp
install -o root -g root -m 0755 /tmp/eksctl /usr/local/bin/eksctl
rm -f /tmp/eksctl

# 6. helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 7. argocd CLI
ARGOCD_VER=$(curl -fsSL https://api.github.com/repos/argoproj/argo-cd/releases/latest | jq -r '.tag_name')
curl -fsSL "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VER}/argocd-linux-amd64" -o /tmp/argocd
install -o root -g root -m 0755 /tmp/argocd /usr/local/bin/argocd
rm -f /tmp/argocd

# 8. AWS CLI v2
cd /tmp
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip
./aws/install --update
rm -rf awscliv2.zip aws/

# 9 Node.js 21
curl -fsSL https://deb.nodesource.com/setup_21.x | bash -
apt-get install -y nodejs

echo "=== PACKER BAKE COMPLETE: $(date) ==="
