# -*- coding: utf-8 -*-
{% from "saemref/map.jinja" import saemref, redis_name, is_docker_build with context %}

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
    - require:
      - pkgrepo: logilab-public-acceptance
    {% else %}{# RedHat #}
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
      - {{ redis_name }}
    {% if grains['os_family'] == 'Debian' %}
      - python-pyramid-redis-sessions
    - require:
      - pkgrepo: logilab-backports
      - pkgrepo: backports
    {% else %}{# RedHat #}
      - pyramid_redis_sessions
      - crontabs
    - require:
      - pkgrepo: logilab_extranet
    {% endif %}

redis-server-service-running:
{% if is_docker_build %}
{#
Salt fail to enable a systemd service if systemd is not running (during the
docker build phase) This is a workaround.
#}
  cmd.run:
    - name: systemctl enable {{ redis_name }}
{% else %}
  service.running:
    - name: {{ redis_name }}
    - enable: true
{% endif %}

{% endif %}
