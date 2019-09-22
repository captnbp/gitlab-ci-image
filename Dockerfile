FROM    ubuntu:18.04

ENV     TERRAFORM_VERSION 0.12.9
ENV     PACKER_VERSION 1.4.3
ENV     VAULT_VERSION 1.2.3

RUN     apt-get update && apt-get install software-properties-common -y && \
        apt-add-repository -y ppa:ansible/ansible && \
        apt-get update && apt-get install ansible python3-pip git curl wget unzip -y && \
        rm -rf /var/lib/apt/lists/*

RUN     pip3 install ansible-modules-hashivault

RUN     wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip && \
        unzip packer_${PACKER_VERSION}_linux_amd64.zip && \
        rm packer_${PACKER_VERSION}_linux_amd64.zip && \
        mv packer /usr/local/bin/packer

RUN     wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
        unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
        rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
        mv terraform /usr/local/bin/terraform

RUN     wget https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip && \
        unzip vault_${VAULT_VERSION}_linux_amd64.zip && \
        rm vault_${VAULT_VERSION}_linux_amd64.zip && \
        mv vault /usr/local/bin/vault

