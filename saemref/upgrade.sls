# -*- coding: utf-8 -*-
{% from "saemref/map.jinja" import saemref with context %}

supervisorctl stop all:
  cmd.run

drop old virtualenv:
  file.absent:
    - name: /home/{{ saemref.instance.user }}/venv
    - require_in:
      - virtualenv: venv

include:
  - saemref.install

cubicweb-upgrade:
  cmd.run:
    - name: /home/{{ saemref.instance.user }}/venv/bin/cubicweb-ctl upgrade --backup-db=y --nostartstop --force --verbosity=0 {{ saemref.instance.name }}
    - user: {{ saemref.instance.user }}
    - env:
        CW_MODE: user
    - require:
      - pip: cubicweb-saem_ref

supervisorctl start all:
  cmd.run:
    - require:
      - cmd: cubicweb-upgrade
