# -*- coding: utf-8 -*-
{% from "saemref/map.jinja" import saemref with context %}

include:
  - saemref.logilab-repo

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
