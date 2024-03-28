FROM ubuntu:latest

ENV PATH="${PATH}:~/.local/bin"

#Install curl and jq
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    jq \
    git \
    vim

#Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv ./kubectl /usr/local/bin && \
    echo $(kubectl version --client)

#install npm and newman
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - &&\
    apt-get install -y nodejs

RUN npm install -g newman
ADD "./newman" /usr/local/bin

#Install Helm
RUN wget https://get.helm.sh/helm-v3.8.2-linux-amd64.tar.gz && \
    tar xvf helm-*-linux-amd64.tar.gz && \
    mv linux-amd64/helm /usr/local/bin

#Install Kustomize
RUN curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash && \
    mv ./kustomize /usr/local/bin
