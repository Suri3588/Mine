FROM jenkins/jnlp-slave

USER root

RUN apt-get update \
    &&  apt-get install software-properties-common --assume-yes \ 
    &&  apt-get -y install curl git jq zip

RUN curl -sL https://installpackages20190301.blob.core.windows.net/yaml2json/yaml2json_linux_amd64 -o yaml2json \
    &&  mv yaml2json /usr/local/bin/yaml2json \
    &&  chmod +x /usr/local/bin/yaml2json \
    &&  curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.16.3/bin/linux/amd64/kubectl \
    &&  chmod +x kubectl && mv kubectl /usr/local/bin/kubectl 

#Install python
RUN apt-get -y install python3-pip python-pip \
    &&  pip3 install --no-cache-dir yq==2.4.1 \
    &&  pip3 install git-pull-request

# Install az utility
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

#Install terraform
RUN wget --quiet https://releases.hashicorp.com/terraform/0.12.19/terraform_0.12.19_linux_amd64.zip\
    && unzip terraform_0.12.19_linux_amd64.zip \
    && mv terraform /usr/bin \
    && rm terraform_0.12.19_linux_amd64.zip

# Install azcopy command
RUN mkdir azcopy_tmp && cd azcopy_tmp \
    && wget -q -O azcopy_v10.tar.gz https://aka.ms/downloadazcopy-v10-linux \
    && tar -xf azcopy_v10.tar.gz --strip-components=1 \
    && mv azcopy /usr/bin \
    && chmod 755 /usr/bin/azcopy \
    && cd .. && rm -rf azcopy_tmp

#Install asible
RUN pip install ansible==2.5.5
RUN pip uninstall cryptography -y&&pip install --ignore-installed cryptography==2.8 # To fix a big with ansible see https://github.com/ansible/ansible/issues/29084

# Install Node.js
RUN apt-get -y install gnupg build-essential \
    &&  curl -sL https://deb.nodesource.com/setup_10.x | bash - \
    &&  apt-get -y install nodejs

WORKDIR /home/jenkins

USER jenkins

ARG AGENT_HASH_VAR
ENV AGENT_HASH=$AGENT_HASH_VAR

ENTRYPOINT ["jenkins-slave"]
