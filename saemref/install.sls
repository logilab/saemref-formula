# -*- coding: utf-8 -*-
{% from "saemref/map.jinja" import saemref, redis_name, is_docker_build with context %}

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

# Patch CubicWeb 3.23.0 (ticket https://www.cubicweb.org/14010345)

{% if grains['os_family'] == 'RedHat' %}
{% set sitepkg = 'site-packages' %}
{% else %}
{% set sitepkg = 'dist-packages' %}
{% endif %}
{% set sqlutils_filepath = ['/usr/lib/python2.7', sitepkg, 'cubicweb/server/sqlutils.py']|join('/') %}

{{ sqlutils_filepath }}:
  pkg.installed:
    - name: patch
  file.patch:
    - source: salt://saemref/files/cubicweb-14010345.patch
    - hash: md5=eccc575024e12d1980f799d5abd49776
    - require:
      - pkg: cube-packages

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
