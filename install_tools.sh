#!/bin/bash
set -euo pipefail
cd /tmp
# shellcheck disable=SC2034
DEBIAN_FRONTEND=noninteractive

echo "Install tools"
apt-get update >/dev/null
apt-get dist-upgrade -y
apt-get install -y --no-install-recommends locales procps lsb-release vim pwgen jq wget curl unzip software-properties-common gpg gettext ca-certificates openssh-client git bzip2
curl -sL --fail --show-error https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee -a /etc/apt/sources.list.d/trivy.list
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg
chmod a+r /usr/share/keyrings/docker.gpg
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list
# shellcheck source=/dev/null
echo \
  "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(source /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update >/dev/null
apt-get install -y --no-install-recommends skopeo htop netcat-openbsd uuid-runtime dnsutils exa fd-find trivy iproute2 nmap iperf3 \
  docker-ce-cli docker-buildx-plugin docker-compose-plugin \
  shellcheck python3-pip python3-setuptools python3-ldap python3-docker python3-venv twine python3-psycopg2 gcc python3-dev \
  mongodb-org-tools mongodb-mongosh \
  clamav-base

# https://wiki.debian.org/Locale#Manually
sed -i "s/# en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen 
locale-gen

# For AMD64 / x86_64
[ "$(uname -m)" = x86_64 ] && ARCH="amd64"
# For ARM64
[ "$(uname -m)" = aarch64 ] && ARCH="arm64"
OS=$(uname |tr '[:upper:]' '[:lower:]')

echo "Install Ansible and ansible-modules-hashivault"
# https://www.linuxuprising.com/2023/03/next-debianubuntu-releases-will-likely.html?m=1
export PIP_BREAK_SYSTEM_PACKAGES=1
pip3 install --no-cache-dir ansible ansible-modules-hashivault openshift passlib hvac elasticsearch virtualenv ipykernel checkov opensearch-py

ln -s "$(which fdfind)" /usr/local/bin/fd

echo "Install kubectl"
curl -sL --fail --show-error "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/${OS}/${ARCH}/kubectl" -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl

echo "Install helm"
HELM_VERSION=$(curl -sL https://api.github.com/repos/helm/helm/releases/latest | jq -r .tag_name)
HELM_DIST="helm-$HELM_VERSION-$OS-$ARCH.tar.gz"
DOWNLOAD_URL="https://get.helm.sh/$HELM_DIST"
CHECKSUM_URL="$DOWNLOAD_URL.sha256"
HELM_TMP_ROOT="$(mktemp -dt helm-installer-XXXXXX)"
HELM_TMP_FILE="$HELM_TMP_ROOT/$HELM_DIST"
HELM_SUM_FILE="$HELM_TMP_ROOT/$HELM_DIST.sha256"
if type "curl" > /dev/null; then
  curl -SsL "$CHECKSUM_URL" -o "$HELM_SUM_FILE"
elif type "wget" > /dev/null; then
  curl -sL --fail --show-error -o "$HELM_SUM_FILE" "$CHECKSUM_URL"
fi
if type "curl" > /dev/null; then
  curl -SsL "$DOWNLOAD_URL" -o "$HELM_TMP_FILE"
elif type "wget" > /dev/null; then
  curl -sL --fail --show-error -o "$HELM_TMP_FILE" "$DOWNLOAD_URL"
fi
# installFile verifies the SHA256 for the file, then unpacks and
# installs it.
HELM_TMP="$HELM_TMP_ROOT/helm"
sum=$(openssl sha1 -sha256 "${HELM_TMP_FILE}" | awk '{print $2}')
expected_sum=$(cat "${HELM_SUM_FILE}")
if [ "$sum" != "$expected_sum" ]; then
  echo "SHA sum of ${HELM_TMP_FILE} does not match. Aborting."
  exit 1
fi
mkdir -p "$HELM_TMP"
tar xf "$HELM_TMP_FILE" -C "$HELM_TMP"
HELM_TMP_BIN="$HELM_TMP/$OS-$ARCH/helm"
cp "$HELM_TMP_BIN" "/usr/local/bin"

echo "Install Packer"
PACKER_VERSION=$(curl -sL "https://api.github.com/repos/hashicorp/packer/releases/latest" | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sL --fail --show-error "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_${OS}_${ARCH}.zip" -o /tmp/packer.zip
unzip -o /tmp/packer.zip >/dev/null
mv -f /tmp/packer /usr/local/bin/packer
rm /tmp/packer.zip

echo "Install Terraform"
TERRAFORM_VERSION=$(curl -sL "https://api.github.com/repos/hashicorp/terraform/releases/latest" | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sL --fail --show-error "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_${OS}_${ARCH}.zip" -o /tmp/terraform.zip
unzip -o terraform.zip >/dev/null
mv -f /tmp/terraform /usr/local/bin/terraform
chown 0755 /usr/local/bin/terraform
rm /tmp/terraform.zip

echo "Install Vault"
VAULT_VERSION=$(curl -sL "https://api.github.com/repos/hashicorp/vault/releases/latest" | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sL --fail --show-error "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_${OS}_${ARCH}.zip" -o /tmp/vault.zip
unzip -o /tmp/vault.zip >/dev/null
mv -f /tmp/vault /usr/local/bin/vault
chown 0755 /usr/local/bin/vault
rm /tmp/vault.zip

echo "Install Minio mc client"
curl -sL --fail --show-error "https://dl.min.io/client/mc/release/${OS}-${ARCH}/mc" -o /usr/local/bin/mc
chmod 0755 /usr/local/bin/mc

echo "Install Restic cli"
RESTIC_VERSION=$(curl -sL "https://api.github.com/repos/restic/restic/releases/latest" | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sL --fail --show-error "https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_${OS}_${ARCH}.bz2" -o /tmp/restic.bz2
bzip2 -d /tmp/restic.bz2
mv /tmp/restic /usr/local/bin/restic
chmod 0755 /usr/local/bin/restic

echo "Install Scaleway scw cli"
SCW_VERSION=$(curl -sL "https://api.github.com/repos/scaleway/scaleway-cli/releases/latest" | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sL --fail --show-error "https://github.com/scaleway/scaleway-cli/releases/download/v${SCW_VERSION}/scaleway-cli_${SCW_VERSION}_${OS}_${ARCH}" -o /usr/local/bin/scw
chmod 0755 /usr/local/bin/scw

echo "Install Hadolint"
HADOLINT_VERSION=$(curl -sL "https://api.github.com/repos/hadolint/hadolint/releases/latest" | jq -r .tag_name)
[ "$(uname -m)" = x86_64 ] && curl -sL --fail --show-error "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-x86_64" -o /usr/local/bin/hadolint
[ "$(uname -m)" = aarch64 ] && curl -sL --fail --show-error "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-arm64" -o /usr/local/bin/hadolint
chmod 0755 /usr/local/bin/hadolint

echo "Install cosign"
curl -sLO --fail --show-error "https://github.com/sigstore/cosign/releases/latest/download/cosign-${OS}-${ARCH}"
mv "cosign-${OS}-${ARCH}" /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign

echo "Install dive"
DIVE_VERSION=$(curl -sL "https://api.github.com/repos/wagoodman/dive/releases/latest" | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sLO --fail --show-error "https://github.com/wagoodman/dive/releases/download/v${DIVE_VERSION}/dive_${DIVE_VERSION}_${OS}_${ARCH}.deb"
apt install "./dive_${DIVE_VERSION}_${OS}_${ARCH}.deb"
rm "./dive_${DIVE_VERSION}_${OS}_${ARCH}.deb"

echo "Install oras"
ORAS_VERSION=$(curl -sL https://api.github.com/repos/oras-project/oras/releases/latest | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sLO --fail --show-error "https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}/oras_${ORAS_VERSION}_${OS}_${ARCH}.tar.gz"
mkdir -p oras-install/
tar -zxf "oras_${ORAS_VERSION}_${OS}_${ARCH}.tar.gz" -C oras-install/
mv oras-install/oras /usr/local/bin/
rm -rf "oras_${ORAS_VERSION}_${OS}_${ARCH}.tar.gz" oras-install/

echo "Install kind"
KIND_VERSION=$(curl -sL https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sL --fail --show-error -o /usr/local/bin/kind "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-${OS}-${ARCH}"
chmod 0755 /usr/local/bin/kind

echo "Install manifest-tool"
MANIFEST_VERSION=$(curl -sL https://api.github.com/repos/estesp/manifest-tool/releases/latest | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sL --fail --show-error -o /tmp/binaries-manifest-tool.tar.gz "https://github.com/estesp/manifest-tool/releases/download/v${MANIFEST_VERSION}/binaries-manifest-tool-${MANIFEST_VERSION}.tar.gz"
tar -zxf /tmp/binaries-manifest-tool.tar.gz "manifest-tool-${OS}-${ARCH}"
mv "manifest-tool-${OS}-${ARCH}" "/usr/local/bin/manifest-tool"
chmod 0755 /usr/local/bin/manifest-tool
rm -rf /tmp/binaries-manifest-tool.tar.gz

echo "Install grype"
GRYPE_VERSION=$(curl -sL "https://api.github.com/repos/anchore/grype/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
curl -sLO --fail --show-error "https://github.com/anchore/grype/releases/download/v${GRYPE_VERSION}/grype_${GRYPE_VERSION}_${OS}_${ARCH}.deb"
apt install "./grype_${GRYPE_VERSION}_${OS}_${ARCH}.deb"
rm "./grype_${GRYPE_VERSION}_${OS}_${ARCH}.deb"

echo "Install syft"
SYFT_VERSION=$(curl -sL "https://api.github.com/repos/anchore/syft/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
curl -sLO --fail --show-error "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_${OS}_${ARCH}.deb"
apt install "./syft_${SYFT_VERSION}_${OS}_${ARCH}.deb"
rm "./syft_${SYFT_VERSION}_${OS}_${ARCH}.deb"

echo "Install yq"
YQ_VERSION=$(curl -sL "https://api.github.com/repos/mikefarah/yq/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
curl -sLO --fail --show-error "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_${OS}_${ARCH}"
mv "./yq_${OS}_${ARCH}" "/usr/local/bin/yq"
chmod 0755 /usr/local/bin/yq

echo "install testssl.sh"
git clone --depth 1 https://github.com/drwetter/testssl.sh.git /usr/local/testssl.sh
chmod 0755 /usr/local/testssl.sh

echo "Install Postgresql client"
curl -sL --fail --show-error https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor > /usr/share/keyrings/postgresql.gpg
echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | tee -a /etc/apt/sources.list.d/pgdg.list
apt-get update >/dev/null
apt-get install -y postgresql-client

wget https://gitlab.com/gitlab-org/terraform-images/-/raw/master/src/bin/gitlab-terraform.sh -O /usr/bin/gitlab-terraform
chmod +x /usr/bin/gitlab-terraform

echo "Install golang"
GO_VERSION=$(curl -sL https://go.dev/VERSION\?m\=text | head -1)
curl -sLO --fail --show-error "https://go.dev/dl/${GO_VERSION}.${OS}-${ARCH}.tar.gz"
rm -rf /usr/local/go && tar -C /usr/local -xzf "${GO_VERSION}.${OS}-${ARCH}.tar.gz"
echo "export PATH=\$PATH:/usr/local/go/bin" >> /etc/profile
rm "./${GO_VERSION}.${OS}-${ARCH}.tar.gz"

echo "Install NodeJS and NPM"
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
NODE_MAJOR=20
echo "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
apt-get update
apt-get install -y nodejs

echo "Cleaning"
rm -rf /var/lib/apt/lists/* /tmp/*
