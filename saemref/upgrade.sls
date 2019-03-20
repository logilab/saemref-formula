# -*- coding: utf-8 -*-
{% from "saemref/map.jinja" import saemref with context %}

include:
  - saemref.install
  - saemref.config
  - saemref.supervisor

supervisorctl stop all:
  cmd.run

drop old virtualenv:
  file.absent:
    - name: /home/{{ saemref.instance.user }}/venv
    - require_in:
      - virtualenv: venv

cubicweb-upgrade:
  cmd.run:
    - name: /home/{{ saemref.instance.user }}/venv/bin/cubicweb-ctl upgrade --backup-db=y --nostartstop --force --verbosity=0 {{ saemref.instance.name }}
    - runas: {{ saemref.instance.user }}
    - env:
        CW_MODE: user
    - require:
      - pip: cubicweb-saem_ref

supervisorctl start all:
  cmd.run:
    - require:
      - cmd: cubicweb-upgrade
