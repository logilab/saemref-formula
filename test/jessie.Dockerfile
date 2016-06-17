FROM debian:jessie

RUN apt-get update && apt-get -y install wget
RUN wget -O - https://repo.saltstack.com/apt/debian/8/amd64/latest/SALTSTACK-GPG-KEY.pub | apt-key add -
RUN echo "deb http://repo.saltstack.com/apt/debian/8/amd64/latest jessie main" > /etc/apt/sources.list.d/saltstack.list
RUN apt-get update && apt-get -y install salt-minion git python-dulwich net-tools curl locales

# Systemd stuff
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do if ! test $i = systemd-tmpfiles-setup.service; then rm -f $i; fi; done) && \
    rm -f /lib/systemd/system/multi-user.target.wants/* && \
    rm -f /etc/systemd/system/*.wants/* && \
    rm -f /lib/systemd/system/local-fs.target.wants/* && \
    rm -f /lib/systemd/system/sockets.target.wants/*udev* && \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*

# Locale settings
RUN echo 'LANG="en_US.UTF-8"' > /etc/default/locale && \
	echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen && update-locale
ENV LANG en_US.UTF-8
CMD ["/sbin/init"]
