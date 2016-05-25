{% from "saemref/map.jinja" import saemref with context %}

include:
  - saemref

cubicweb-db-init:
  cmd.run:
    - name: cubicweb-ctl db-init -a {{ saemref.instance.name }}
    - user: {{ saemref.instance.user }}
    - env:
        CW_MODE: user

