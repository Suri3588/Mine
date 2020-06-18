# This is a jenkins slave agent that has all the parts it needs to run
# the branch prep steps.
FROM jenkins/jnlp-slave

USER root

# Force us to use the bash shell
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Install base dependencies
RUN apt-get update \
    &&  apt-get install -y  apt-transport-https \
                            build-essential \
                            ca-certificates \
                            curl \
                            git \
                            libssl-dev \
                            wget \
                            bsdtar \
                            xvfb \
    &&  apt-get -y autoclean

# from https://stackoverflow.com/questions/47203812/package-chromium-browser-has-no-installation-candidate
# install manually all the missing libraries
RUN apt-get install -y gconf-service \
                       libasound2 \
                       libatk1.0-0 \
                       libcairo2 \
                       libcups2 \
                       libfontconfig1 \
                       libgdk-pixbuf2.0-0 \
                       libgtk-3-0 \
                       libnspr4 \
                       libpango-1.0-0 \
                       libxss1 \
                       fonts-liberation \
                       libappindicator1 \
                       libnss3 \
                       lsb-release \
                       xdg-utils \
                       chromium

# Now we can install NVM & NODE
ENV NVM_DIR /usr/local/nvm
ENV NODE_VERSION 10.16.3

RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh | bash \
    && source $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default \
    && npm install -g node-gyp

# Get Mongo installed to run the seed tests
# RUN lsb_release -a # to determine the distro
RUN \
  wget -qO - https://www.mongodb.org/static/pgp/server-4.0.asc | apt-key add - && \
  echo "deb http://repo.mongodb.org/apt/debian stretch/mongodb-org/4.0 main" | tee /etc/apt/sources.list.d/mongodb-org-4.0.list && \
  apt-get update && \
  apt-get install -y mongodb-org

RUN \
  set -eo pipefail && \
  mkdir -p /data/db && \
  chown -R jenkins:jenkins /data/db && \
  chmod -R 700 /data/db

# Install the rest of the build chain and meteor 
RUN runuser -l jenkins -c "curl https://install.meteor.com/?release=1.8.0.2 | sed -e 's/tar -/bsdtar -/g' | sh" \
    &&  apt-get -y autoclean \
    &&  chown -R jenkins:jenkins /home/jenkins \
    &&  chmod a+rwx /home/jenkins

USER jenkins

WORKDIR /home/jenkins

ENV NODE_PATH $NVM_DIR/versions/node/v$NODE_VERSION/lib/node_modules
ENV PATH      /home/jenkins/.meteor:$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH
ARG AGENT_HASH_VAR
ENV AGENT_HASH=$AGENT_HASH_VAR

ADD run.sh /tmp/run.sh
ENTRYPOINT ["/tmp/run.sh"]
