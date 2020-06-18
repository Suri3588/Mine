FROM jenkins/jnlp-slave

USER root

RUN apt-get update \
    &&  apt-get -y install curl gnupg build-essential git \
    &&  curl -sL https://deb.nodesource.com/setup_10.x | bash - \
    &&  apt-get -y install nodejs \
    &&  npm install  \
    &&  chmod a+rwx /home/jenkins

WORKDIR /home/jenkins

USER jenkins

RUN ls -al /usr/local/bin/

ARG AGENT_HASH_VAR
ENV AGENT_HASH=$AGENT_HASH_VAR

ENTRYPOINT ["jenkins-slave"]
