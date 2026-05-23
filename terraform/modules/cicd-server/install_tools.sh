buntu@ip-172-31-10-17:~/Wanderlust-Mega-Project/terraform/modules/cicd-server$ cat install_tools.sh
#!/bin/bash
# ============================================================
# Core Host Initialization Script
# Bootstraps baseline system runtimes, persistence storage mounts,
# and restores state trees from centralized cold store S3 buckets.
# Added: Automated SonarQube Engine & Zero-Wizard Jenkins Security
# Fixes: Premature default service initialization race conditions
# Updates: Forced personal account synchronization parameters
# ============================================================
set -e
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== JENKINS SERVER BOOTSTRAP STARTING: $(date) ==="

# ── 1. Package Manager Lock Interceptor ───────────────────────
sleep 20
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
  echo "[GUARD] Package database lock active. Retrying execution context in 5s..."
  sleep 5
done

# ── 2. System Dependency Baselines ────────────────────────────
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y \
  ca-certificates curl software-properties-common \
  fontconfig openjdk-21-jre unzip wget tar jq
echo "[STATUS] Core dependencies provisioned successfully."

sudo mkdir -p /usr/share/keyrings /etc/apt/keyrings /etc/apt/sources.list.d

# ── 3. Upstream Repository Signing Engine Keys ────────────────
sudo wget -q -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
sudo chmod a+r /usr/share/keyrings/jenkins-keyring.asc
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo wget -q -O /etc/apt/keyrings/docker.asc \
  https://download.docker.com/linux/ubuntu/gpg
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo wget -q -O /usr/share/keyrings/trivy-keyring.asc \
  https://aquasecurity.github.io/trivy-repo/deb/public.key
sudo chmod a+r /usr/share/keyrings/trivy-keyring.asc
echo "deb [signed-by=/usr/share/keyrings/trivy-keyring.asc] https://aquasecurity.github.io/trivy-repo/deb noble main" \
  | sudo tee /etc/apt/sources.list.d/trivy.list > /dev/null

# ── 4. Runtime Binaries Installation ──────────────────────────
sudo apt-get update -y
sudo apt-get install -y \
  jenkins \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
  trivy

# [FIX] Immediately intercept and pause the background default unconfigured service
echo "[STATUS] Stopping raw default Jenkins instance to prevent storage tree pollution..."
sudo systemctl stop jenkins || true

sudo usermod -aG docker ubuntu
sudo usermod -aG docker jenkins
sudo systemctl daemon-reload
sudo systemctl enable jenkins docker

# ── 5. Cloud Automation Engineering Toolkits ───────────────────
curl -fsSL https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl -o /tmp/kubectl
sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
rm -f /tmp/kubectl

curl -fsSL https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz | tar -xz -C /tmp
sudo install -o root -g root -m 0755 /tmp/eksctl /usr/local/bin/eksctl
rm -f /tmp/eksctl

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get-helm.sh
chmod +x /tmp/get-helm.sh
/tmp/get-helm.sh
rm -f /tmp/get-helm.sh

ARGOCD_VERSION=$(curl -fsSL https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep '"tag_name"' | sed 's/.*"tag_name": "\(.*\)".*/\1/')
curl -fsSL "https://github.com/argoproj/argo-cd/releases/download/$ARGOCD_VERSION/argocd-linux-amd64" -o /tmp/argocd
sudo install -o root -g root -m 0755 /tmp/argocd /usr/local/bin/argocd
rm -f /tmp/argocd

cd /tmp
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install --update
rm -rf awscliv2.zip aws/

# ── 6. Local Region Scope Bindings ────────────────────────────
sudo -u ubuntu mkdir -p /home/ubuntu/.aws
sudo tee /home/ubuntu/.aws/config > /dev/null << EOF
[default]
region = ${region}
output = json
EOF
sudo chown -R ubuntu:ubuntu /home/ubuntu/.aws

# ── 7. Storage Engine Mapping and File Mount Blocks ──────────
DEVICE=""
for i in $(seq 1 12); do
  if [ -b /dev/nvme1n1 ]; then
    DEVICE=/dev/nvme1n1; break
  elif [ -b /dev/xvdf ]; then
    DEVICE=/dev/xvdf; break
  fi
  sleep 5
done

if [ -z "$DEVICE" ]; then
  JENKINS_HOME="/var/lib/jenkins"
  SQ_BASE_DIR="/var/lib/sonarqube"
  sudo mkdir -p "$JENKINS_HOME"
else
  if ! sudo blkid $DEVICE > /dev/null 2>&1; then
    sudo mkfs.ext4 -L jenkins-data $DEVICE
  fi

  sudo mkdir -p /mnt/jenkins-data
  sudo mount $DEVICE /mnt/jenkins-data

  DEVICE_UUID=$(sudo blkid -s UUID -o value $DEVICE)
  grep -q "$DEVICE_UUID" /etc/fstab || echo "UUID=$DEVICE_UUID /mnt/jenkins-data ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

  sudo mkdir -p /mnt/jenkins-data/jenkins-home

  JENKINS_HOME="/mnt/jenkins-data/jenkins-home"
  SQ_BASE_DIR="/mnt/jenkins-data/sonarqube"
fi

# Globalized Systemd profile injection to enforce custom home directory structures
sudo mkdir -p /etc/systemd/system/jenkins.service.d
sudo tee /etc/systemd/system/jenkins.service.d/override.conf > /dev/null << OVERRIDE
[Service]
Environment="JENKINS_HOME=$${JENKINS_HOME}"
Environment="JAVA_OPTS=-Djenkins.install.runSetupWizard=false -Djava.awt.headless=true"
OVERRIDE

# Secure proper user permissions boundaries across mount nodes
sudo chown -R jenkins:jenkins "$JENKINS_HOME"
if [ -d "/mnt/jenkins-data" ]; then
  sudo chown -R jenkins:jenkins /mnt/jenkins-data
fi

sudo systemctl daemon-reload

# ── 8. Cold Store Backup Synchronizations ─────────────────────
BACKUP_BUCKET="${backup_s3_bucket}"
BACKUP_PREFIX="jenkins-backup/${environment}"

# Secure execution utilizing native IAM instance profiles
BACKUP_EXISTS=$(aws s3 ls "s3://$BACKUP_BUCKET/$BACKUP_PREFIX/" --region ${region} 2>/dev/null | wc -l || echo 0)

if [ "$BACKUP_EXISTS" -gt 0 ]; then
  sudo aws s3 sync "s3://$BACKUP_BUCKET/$BACKUP_PREFIX/" "$JENKINS_HOME/" --region ${region} --exclude "*/workspace/*" --exclude "*.tmp"
  sudo chown -R jenkins:jenkins $JENKINS_HOME
fi

# ── 8b. Jenkins Automation Init Security Engine ────────────────
# Forced Reset Profile Engine: Removes conditional wrappers to prevent EBS memory lockouts
echo "[STATUS] Injecting Groovy security matrix baseline configurations..."
sudo mkdir -p "$JENKINS_HOME/init.groovy.d"

sudo tee "$JENKINS_HOME/init.groovy.d/basic-security.groovy" > /dev/null << 'EOF'
import jenkins.model.*
import hudson.security.*
import java.util.logging.Logger

def logger = Logger.getLogger("init.groovy")
def instance = Jenkins.getInstance()

logger.info("[AUTOMATION] Synchronizing customized security profiles on persistent drive partition...")

// Forces the direct overwrite/generation of your specific user realm credentials
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("shubhamsingh_8873", "Skynet@887382")
instance.setSecurityRealm(hudsonRealm)

// Maps your custom human display metadata to the account structure
def user = hudson.model.User.get("shubhamsingh_8873")
user.setFullName("Shubham Singh")
user.save()

// Closes unauthenticated perimeter vulnerabilities
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousJobStatusPermission(false)
instance.setAuthorizationStrategy(strategy)

instance.save()
logger.info("[AUTOMATION] Security infrastructure verification complete. Custom credentials active.")
EOF
sudo chown -R jenkins:jenkins "$JENKINS_HOME/init.groovy.d"

# ── 8c. Containerized SonarQube Infrastructure Engine ──────────
echo "[STATUS] Applying host kernel optimizations for SonarQube Elasticsearch indices..."
sudo sysctl -w vm.max_map_count=524288
grep -q "vm.max_map_count=524288" /etc/sysctl.conf || echo "vm.max_map_count=524288" | sudo tee -a /etc/sysctl.conf

echo "[STATUS] Mapping localized sub-directories for decoupled persistent state..."
sudo mkdir -p "$SQ_BASE_DIR/data" "$SQ_BASE_DIR/extensions" "$SQ_BASE_DIR/logs"
sudo chown -R 1000:1000 "$SQ_BASE_DIR"

if [ "$(sudo docker ps -a -q -f name=sonarqube)" ]; then
    echo "[STATUS] Active container detected. Synchronizing infrastructure daemon states..."
    sudo docker start sonarqube
else
    echo "[STATUS] Instantiating isolated container runtime for SonarQube..."
    sudo docker run -d \
      --name sonarqube \
      --restart always \
      -p 9000:9000 \
      -v "$SQ_BASE_DIR/data:/opt/sonarqube/data" \
      -v "$SQ_BASE_DIR/extensions:/opt/sonarqube/extensions" \
      -v "$SQ_BASE_DIR/logs:/opt/sonarqube/logs" \
      sonarqube:community
fi

# ── 9. Service Startup Phase ──────────────────────────────────
# Using restart ensures systemd flushes raw memory and cleanly binds your 30GB home volume parameters
sudo systemctl restart jenkins
sudo systemctl start docker

# ── 10. Scheduling Engine Recurrent Automation Tasks ──────────
sudo tee /etc/cron.d/jenkins-s3-backup > /dev/null << CRONEOF
0 2 * * * root aws s3 sync $JENKINS_HOME s3://$BACKUP_BUCKET/$BACKUP_PREFIX/ --region ${region} --exclude "*/workspace/*" --exclude "*.tmp" --exclude "*/cache/*" >> /var/log/jenkins-backup.log 2>&1
CRONEOF
sudo chmod 644 /etc/cron.d/jenkins-s3-backup

# ── 11. IMDSv2 Endpoint Information Extraction ────────────────
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
MASTER_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

echo "=========================================================="
echo "      TOOL INFRASTRUCTURE INITIALIZED VERIFIED (ZHI)     "
echo "=========================================================="
echo "[INFO] Target Host Infrastructure Active Node Platform Details:"
echo "[INFO] Internal Persistent Path Directory: $JENKINS_HOME"
echo "[INFO] Continuous Integration Hub UI:    http://$MASTER_IP:8080"
echo "[INFO] Automated Security Scan Panel:    http://$MASTER_IP:9000"
echo "=========================================================="
ubuntu@ip-172-31-10-17:~/Wanderlust-Mega-Project/terraform/modules/cicd-serv
