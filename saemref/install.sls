# -*- coding: utf-8 -*-
{% from "saemref/map.jinja" import saemref with context %}

{% if grains['os_family'] == 'Debian' %}

{% elif grains['os_family'] == 'RedHat' %}

include:
  - epel

logilab_extranet:
  pkgrepo.managed:
    - humanname: Logilab extranet BRDX $releasever $basearch
    - baseurl: https://extranet.logilab.fr/static/BRDX/rpms/epel-$releasever-$basearch
    - gpgcheck: 0
{% endif %}

cubicweb-saem-ref:
  pkg.installed:
    - require:
      - pkgrepo: logilab_extranet

create-saemref-user:
  user.present:
    - name: {{ saemref.instance.user }}

cubicweb-create:
  cmd.run:
    - name: cubicweb-ctl create --no-db-create -a saem_ref {{ saemref.instance.name }}
    - creates: /home/{{ saemref.instance.user }}/etc/cubicweb.d/{{ saemref.instance.name }}
    - user: {{ saemref.instance.user }}
    - env:
        CW_MODE: user
    - require:
        - pkg: cubicweb-saem-ref
        - user: {{ saemref.instance.user }}
