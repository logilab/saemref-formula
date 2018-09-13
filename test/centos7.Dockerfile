FROM centos:7

RUN yum -y install epel-release && \
    # salt -> libgit2 -> http-parser which is currently broken on centos 7
    # https://docs.saltstack.com/en/latest/topics/tutorials/gitfs.html#redhat-pygit2-issues
    yum -y install https://kojipkgs.fedoraproject.org//packages/http-parser/2.0/5.20121128gitcd01361.el7/x86_64/http-parser-2.0-5.20121128gitcd01361.el7.x86_64.rpm && \
    yum -y install https://repo.saltstack.com/yum/redhat/salt-repo-2016.11-2.el7.noarch.rpm && \
    yum clean expire-cache && \
    yum -y install systemd-sysv && \
    yum -y install salt-minion python-pygit2 git net-tools libgit2-devel python-devel gcc


RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done) && \
    rm -f /lib/systemd/system/multi-user.target.wants/* && \
    rm -f /etc/systemd/system/*.wants/* && \
    rm -f /lib/systemd/system/local-fs.target.wants/* && \
    rm -f /lib/systemd/system/sockets.target.wants/*udev* && \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl* && \
    rm -f /lib/systemd/system/basic.target.wants/* && \
    rm -f /lib/systemd/system/anaconda.target.wants/*

ENV LANG en_US.UTF-8
CMD ["/usr/sbin/init"]
