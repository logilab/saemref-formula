# -*- coding: utf-8 -*-
# vim: ft=jinja et
{% from "saemref/map.jinja" import saemref with context %}

include:
  - epel

logilab_extranet:
  pkgrepo.managed:
    - humanname: Logilab extranet BRDX $releasever $basearch
    - baseurl: https://extranet.logilab.fr/static/BRDX/rpms/epel-$releasever-$basearch
    - gpgcheck: 0

cubicweb-saem-ref:
  pkg.installed:
    - require:
      - pkgrepo: logilab_extranet

create-saemref-user:
  user.present:
    - name: {{ saemref.instance.user }}

cubicweb-create:
  cmd.run:
    - name: cubicweb-ctl create -Sa saem_ref {{ saemref.instance.name }}
    - creates: /home/{{ saemref.instance.user }}/etc/cubicweb.d/{{ saemref.instance.name }}
    - user: {{ saemref.instance.user }}
    - env:
        CW_MODE: user
    - require:
        - pkg: cubicweb-saem-ref
        - user: {{ saemref.instance.user }}

cubicweb-config:
  file.managed:
    - name: /home/{{ saemref.instance.user }}/etc/cubicweb.d/{{ saemref.instance.name }}/sources
    - source: salt://saemref/templates/sources.j2
    - template: jinja
    - require:
      - cmd: cubicweb-create

python-pip:
  pkg.installed

upgrade-pip:
  pip.installed:
    - name: pip
    - upgrade: true

upgrade-setuptools:
  pip.installed:
    - name: setuptools
    - upgrade: true

supervisor:
  pip.installed

/etc/init.d/supervisor:
  file.managed:
    - source: salt://saemref/files/supervisor.init

/etc/supervisord.conf:
  file.managed:
    - source: salt://saemref/files/supervisord.conf
