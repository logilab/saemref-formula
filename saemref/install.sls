# -*- coding: utf-8 -*-
{% from "saemref/map.jinja" import saemref with context %}

include:
  - saemref.logilab-repo

cube-packages:
  pkg.latest:
    - pkgs:
      - cubicweb-saem-ref
    {% if grains['os_family'] == 'Debian' %}
      - cubicweb-ctl
      - cubicweb-server
      - cubicweb-twisted
    - skip_verify: true {# FIXME: key expired... #}
    - require:
      - pkgrepo: logilab-public-acceptance
    {% else %}{# RedHat #}
    - require:
      - pkgrepo: logilab_extranet
    {% endif %}

{% if grains['os_family'] == 'Debian' %}
# FIXME: https://www.logilab.org/ticket/6302914 workaround
python-logilab-common:
  pkg.installed:
    - version: 1.1.0-1
{% endif %}

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
        - pkg: cube-packages
        - user: {{ saemref.instance.user }}
