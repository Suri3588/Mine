FROM jenkins/jenkins

RUN /usr/local/bin/install-plugins.sh git
RUN /usr/local/bin/install-plugins.sh git-client
RUN /usr/local/bin/install-plugins.sh github
RUN /usr/local/bin/install-plugins.sh credentials
RUN /usr/local/bin/install-plugins.sh blueocean
RUN /usr/local/bin/install-plugins.sh matrix-auth
RUN /usr/local/bin/install-plugins.sh matrix-project
RUN /usr/local/bin/install-plugins.sh azure-container-agents
RUN /usr/local/bin/install-plugins.sh azure-container-registry-tasks

USER jenkins
