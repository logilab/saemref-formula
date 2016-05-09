FROM centos:6

RUN yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm && \
    yum -y install https://repo.saltstack.com/yum/redhat/salt-repo-2015.8-2.el6.noarch.rpm && \
    yum clean expire-cache && \
    yum -y install salt-minion python-pygit2 git

ENV LANG en_US.UTF-8
CMD ["/sbin/init"]
