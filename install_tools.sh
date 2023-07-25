#!/bin/bash
set -euo pipefail
cd /tmp
DEBIAN_FRONTEND=noninteractive

echo "Install tools"
apt-get update >/dev/null
apt-get install -y --no-install-recommends vim pwgen jq wget curl unzip software-properties-common gpg gettext ca-certificates openssh-client git bzip2
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb buster main" | tee -a /etc/apt/sources.list.d/trivy.list
apt-get update >/dev/null
apt-get install -y --no-install-recommends trivy
apt-get dist-upgrade -y

echo "Install kubectl"
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl >/dev/null
chmod +x /tmp/kubectl
mv -f /tmp/kubectl /usr/local/bin/kubectl

echo "Install helm"
HELM_INSTALL_DIR="/usr/local/bin"
ARCH="amd64"
latest_release_url="https://github.com/helm/helm/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/helm/helm/releases/tag/v3.' | head -n 1 | cut -d '"' -f 6 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}')
OS=$(echo `uname`|tr '[:upper:]' '[:lower:]')
HELM_DIST="helm-$TAG-$OS-$ARCH.tar.gz"
DOWNLOAD_URL="https://get.helm.sh/$HELM_DIST"
CHECKSUM_URL="$DOWNLOAD_URL.sha256"
HELM_TMP_ROOT="$(mktemp -dt helm-installer-XXXXXX)"
HELM_TMP_FILE="$HELM_TMP_ROOT/$HELM_DIST"
HELM_SUM_FILE="$HELM_TMP_ROOT/$HELM_DIST.sha256"
echo "Downloading $DOWNLOAD_URL"
if type "curl" > /dev/null; then
  curl -SsL "$CHECKSUM_URL" -o "$HELM_SUM_FILE"
elif type "wget" > /dev/null; then
  wget -q -O "$HELM_SUM_FILE" "$CHECKSUM_URL"
fi
if type "curl" > /dev/null; then
  curl -SsL "$DOWNLOAD_URL" -o "$HELM_TMP_FILE"
elif type "wget" > /dev/null; then
  wget -q -O "$HELM_TMP_FILE" "$DOWNLOAD_URL"
fi
# installFile verifies the SHA256 for the file, then unpacks and
# installs it.
HELM_TMP="$HELM_TMP_ROOT/helm"
sum=$(openssl sha1 -sha256 ${HELM_TMP_FILE} | awk '{print $2}')
expected_sum=$(cat ${HELM_SUM_FILE})
if [ "$sum" != "$expected_sum" ]; then
  echo "SHA sum of ${HELM_TMP_FILE} does not match. Aborting."
  exit 1
fi
mkdir -p "$HELM_TMP"
tar xf "$HELM_TMP_FILE" -C "$HELM_TMP"
HELM_TMP_BIN="$HELM_TMP/$OS-$ARCH/helm"
echo "Preparing to install helm into ${HELM_INSTALL_DIR}"
cp "$HELM_TMP_BIN" "$HELM_INSTALL_DIR"
echo "helm installed into $HELM_INSTALL_DIR/helm"

echo "Install Packer"
latest_release_url="https://github.com/hashicorp/packer/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/hashicorp/packer/releases/tag/v.' | grep -v beta | grep -v rc | head -n 1 | cut -d '"' -f 6 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}' | cut -d 'v' -f2)
wget "https://releases.hashicorp.com/packer/${TAG}/packer_${TAG}_linux_amd64.zip" -O /tmp/packer.zip >/dev/null
unzip /tmp/packer.zip >/dev/null
mv -f /tmp/packer /usr/local/bin/packer
rm /tmp/packer.zip

echo "Install Terraform"
latest_release_url="https://github.com/hashicorp/terraform/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/hashicorp/terraform/releases/tag/v.' | grep -v beta | grep -v rc | head -n 1 | cut -d '"' -f 6 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}' | cut -d 'v' -f2)
wget "https://releases.hashicorp.com/terraform/${TAG}/terraform_${TAG}_linux_amd64.zip" -O /tmp/terraform.zip >/dev/null
unzip terraform.zip >/dev/null
mv -f /tmp/terraform /usr/local/bin/terraform
chown 755 /usr/local/bin/terraform
rm /tmp/terraform.zip

echo "Install Vault"
latest_release_url="https://github.com/hashicorp/vault/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/hashicorp/vault/releases/tag/v.' | grep -v beta | grep -v rc | head -n 1 | cut -d '"' -f 6 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}' | cut -d 'v' -f2)
wget "https://releases.hashicorp.com/vault/${TAG}/vault_${TAG}_linux_amd64.zip" -O /tmp/vault.zip >/dev/null
unzip /tmp/vault.zip >/dev/null
mv -f /tmp/vault /usr/local/bin/vault
chown 755 /usr/local/bin/vault
rm /tmp/vault.zip

echo "Install Minio mc client"
wget "https://dl.min.io/client/mc/release/linux-amd64/mc" -O /usr/local/bin/mc >/dev/null
chmod 755 /usr/local/bin/mc

echo "Install Restic cli"
latest_release_url="https://github.com/restic/restic/releases/"
TAG=$(curl -Ls $latest_release_url | grep 'href="/restic/restic/releases/tag/v.' | grep -v beta | grep -v rc | head -n 1 | cut -d '"' -f 6 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}' | cut -d 'v' -f2)
wget "https://github.com/restic/restic/releases/download/v${TAG}/restic_${TAG}_linux_amd64.bz2" -O /tmp/restic.bz2 >/dev/null
bzip2 -d /tmp/restic.bz2
mv /tmp/restic /usr/local/bin/restic
chmod 755 /usr/local/bin/restic

echo "Install Scaleway scw cli"
#latest_release_url="https://github.com/scaleway/scaleway-cli/releases/"
#TAG=$(curl -Ls $latest_release_url | grep 'href="/scaleway/scaleway-cli/releases/tag/v.' | grep -v beta | grep -v rc | head -n 1 | cut -d '"' -f 2 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}' | cut -d 'v' -f2)
TAG=2.16.1
wget "https://github.com/scaleway/scaleway-cli/releases/download/v${TAG}/scaleway-cli_${TAG}_linux_amd64" -O /usr/local/bin/scw >/dev/null
chmod 755 /usr/local/bin/scw

echo "Install Hadolint"
latest_release_url="https://github.com/hadolint/hadolint/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/hadolint/hadolint/releases/tag/v.' | grep -v rc | head -n 1 | cut -d '"' -f 6 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}')
wget "https://github.com/hadolint/hadolint/releases/download/${TAG}/hadolint-Linux-x86_64" -O /usr/local/bin/hadolint >/dev/null
chmod 755 /usr/local/bin/hadolint

echo "Install cosign"
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
mv cosign-linux-amd64 /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign

echo "Install dive"
export DIVE_VERSION=$(curl -sL "https://api.github.com/repos/wagoodman/dive/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
curl -OL https://github.com/wagoodman/dive/releases/download/v${DIVE_VERSION}/dive_${DIVE_VERSION}_linux_amd64.deb
apt install ./dive_${DIVE_VERSION}_linux_amd64.deb

echo "Install oras"
export ORAS_VERSION=$(curl https://api.github.com/repos/oras-project/oras/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
curl -LO "https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}/oras_${ORAS_VERSION}_linux_amd64.tar.gz"
mkdir -p oras-install/
tar -zxf oras_${ORAS_VERSION}_*.tar.gz -C oras-install/
mv oras-install/oras /usr/local/bin/
rm -rf oras_${ORAS_VERSION}_*.tar.gz oras-install/

echo "Install Ansible and ansible-modules-hashivault"
apt-get install -y --no-install-recommends python3-pip python3-venv twine python3-docker python3-psycopg2 postgresql-client-14
pip3 install --no-cache-dir ansible ansible-modules-hashivault tox virtualenv twine passlib ansible-lint checkov opensearch-py

echo "Install NodeJS and NPM"
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

wget https://gitlab.com/gitlab-org/terraform-images/-/raw/master/src/bin/gitlab-terraform.sh -O /usr/bin/gitlab-terraform
chmod +x /usr/bin/gitlab-terraform

echo "Cleaning"
rm -rf /var/lib/apt/lists/* /tmp/*
