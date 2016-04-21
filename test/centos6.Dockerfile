FROM centos:6

ADD test/bootstrap-salt.sh /tmp/bootstrap-salt.sh
RUN bash /tmp/bootstrap-salt.sh -X && rm /tmp/bootstrap-salt.sh
RUN yum -y update && yum -y install python-pygit2 git

ENV LANG en_US.UTF-8
