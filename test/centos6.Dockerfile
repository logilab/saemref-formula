FROM centos:6

RUN yum -y install epel-release && \
    yum -y install https://repo.saltstack.com/yum/redhat/salt-repo-latest-1.el6.noarch.rpm && \
    yum clean expire-cache && \
    yum -y install salt-minion python-pygit2 git

ENV LANG en_US.UTF-8
CMD ["/sbin/init"]
