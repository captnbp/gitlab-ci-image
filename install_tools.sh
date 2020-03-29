#!/bin/bash
cd /tmp
DEBIAN_FRONTEND=noninteractive

echo "Install kubectl"
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl >/dev/null
chmod +x /tmp/kubectl
mv -f /tmp/kubectl /usr/local/bin/kubectl

echo "Install helm"
HELM_INSTALL_DIR="/usr/local/bin"
ARCH="amd64"
latest_release_url="https://github.com/helm/helm/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/helm/helm/releases/tag/v3.' | grep -v no-underline | head -n 1 | cut -d '"' -f 2 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}')
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

echo "Install tools"
apt-get update >/dev/null
apt-get install -y vim pwgen jq wget curl unzip software-properties-common gpg gettext

echo "Install Packer"
latest_release_url="https://github.com/hashicorp/packer/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/hashicorp/packer/releases/tag/v.' | grep -v no-underline | grep -v rc | head -n 1 | cut -d '"' -f 2 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}' | cut -d 'v' -f2)
wget "https://releases.hashicorp.com/packer/${TAG}/packer_${TAG}_linux_amd64.zip" -O /tmp/packer.zip >/dev/null
unzip /tmp/packer.zip >/dev/null
mv -f /tmp/packer /usr/local/bin/packer
rm /tmp/packer.zip

echo "Install Terraform"
latest_release_url="https://github.com/hashicorp/terraform/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/hashicorp/terraform/releases/tag/v.' | grep -v no-underline | grep -v rc | head -n 1 | cut -d '"' -f 2 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}' | cut -d 'v' -f2)
wget "https://releases.hashicorp.com/terraform/${TAG}/terraform_${TAG}_linux_amd64.zip" -O /tmp/terraform.zip >/dev/null
unzip terraform.zip >/dev/null
mv -f /tmp/terraform /usr/local/bin/terraform
chown 755 /usr/local/bin/terraform
rm /tmp/terraform.zip

echo "Install Vault"
latest_release_url="https://github.com/hashicorp/vault/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/hashicorp/vault/releases/tag/v.' | grep -v no-underline | grep -v rc | head -n 1 | cut -d '"' -f 2 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}' | cut -d 'v' -f2)
wget "https://releases.hashicorp.com/vault/${TAG}/vault_${TAG}_linux_amd64.zip" -O /tmp/vault.zip >/dev/null
unzip /tmp/vault.zip >/dev/null
mv -f /tmp/vault /usr/local/bin/vault
chown 755 /usr/local/bin/vault
rm /tmp/vault.zip

echo "Install k9s"
latest_release_url="https://github.com/derailed/k9s/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/derailed/k9s/releases/tag/v' | grep -v no-underline  | grep -v rc | head -n 1 | cut -d '"' -f 2 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}')
wget "https://github.com/derailed/k9s/releases/download/${TAG}/k9s_Linux_x86_64.tar.gz" -O /tmp/k9s.tar.gz >/dev/null
tar zxf /tmp/k9s.tar.gz >/dev/null
mv -f /tmp/k9s /usr/local/bin/k9s
chown 755 /usr/local/bin/k9s
rm /tmp/k9s.tar.gz

echo "Install Minio mc client"
wget "https://dl.min.io/client/mc/release/linux-amd64/mc" -O /usr/local/bin/mc >/dev/null
chmod 755 /usr/local/bin/mc

echo "Install Hadolint"
latest_release_url="https://github.com/hadolint/hadolint/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/hadolint/hadolint/releases/tag/v.' | grep -v no-underline | grep -v rc | head -n 1 | cut -d '"' -f 2 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}')
wget "https://github.com/hadolint/hadolint/releases/download/${TAG}/hadolint-Linux-x86_64" -O /usr/local/bin/hadolint >/dev/null
chmod 755 /usr/local/bin/hadolint

echo "Install Jfrog CLI"
wget https://api.bintray.com/content/jfrog/jfrog-cli-go/\$latest/jfrog-cli-linux-amd64/jfrog?bt_package=jfrog-cli-linux-amd64 -O /usr/local/bin/jfrog
chmod 755 /usr/local/bin/jfrog

echo "Install docker"
/usr/bin/curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh  >/dev/null
usermod -aG docker coder
latest_release_url="https://github.com/docker/compose/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/docker/compose/releases/tag/' | grep -v no-underline | grep -v rc | head -n 1 | cut -d '"' -f 2 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}')
curl -L https://github.com/docker/compose/releases/download/${TAG}/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
apt-get install -y python3-docker

echo "Install Ansible and ansible-modules-hashivault"
apt-get install -y python3-pip
pip3 install ansible ansible-modules-hashivault

echo "Cleaning"
rm -rf /var/lib/apt/lists/*