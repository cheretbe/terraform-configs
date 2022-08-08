FROM geerlingguy/docker-ubuntu2004-ansible

#COPY docker_sshd_config.sh .
#RUN ./docker_sshd_config.sh
RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get -qq install curl wget git openssh-server

COPY entry_point_command.sh .