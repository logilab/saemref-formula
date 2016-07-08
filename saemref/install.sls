# -*- coding: utf-8 -*-
{% from "saemref/map.jinja" import saemref with context %}

include:
  - saemref.logilab-repo
{% if grains['os_family'] == 'RedHat' %}
  - epel
  - postgres.upstream
{% endif %}


cube-packages:
  pkg.latest:
    - pkgs:
      - cubicweb-saem-ref
    {% if grains['os_family'] == 'Debian' %}
      - cubicweb-ctl
      - cubicweb-server
      - cubicweb-twisted
      - postgresql-client
    - require:
      - pkgrepo: logilab-public-acceptance
    {% else %}{# RedHat #}
      - postgresql94
    - require:
      - pkgrepo: logilab_extranet
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

{% if saemref.instance.wsgi %}

wsgi-packages:
  pkg.installed:
    - pkgs:
      - pyramid-cubicweb
      - uwsgi
      - uwsgi-plugin-python
    {% if grains['os_family'] == 'Debian' %}
    - require:
      - pkgrepo: logilab-backports
      - pkgrepo: backports
    {% else %}{# RedHat #}
      - crontabs
    - require:
      - pkgrepo: logilab_extranet
    {% endif %}

{% endif %}
