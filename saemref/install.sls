# -*- coding: utf-8 -*-
{% from "saemref/map.jinja" import saemref with context %}

{% if grains['os_family'] == 'RedHat' %}
include:
  - postgres.upstream
  - postgres.client

epel-release:
  pkg.installed
{% endif %}

pip-setuptools:
  pkg.latest:
    - pkgs:
    {% if grains['os_family'] == 'Debian' %}
      - python-pip
    {% else %}{# RedHat #}
      - python2-pip
    {% endif %}
  pip.installed:
    - name: setuptools
    - ignore_installed: true

cube-packages:
  pkg.latest:
    - pkgs:
    {% if grains['os_family'] == 'Debian' %}
      - postgresql-client
      - graphviz
      - python-all-dev
      - libgecode-dev
      - g++
    {% else %}{# RedHat #}
      - graphviz-gd
      - python-devel
      - gecode-devel
      - gcc-c++
    {% endif %}
      - gettext
      - python-virtualenv
      - python-lxml
      - python-psycopg2
    - require:
      - pip: pip-setuptools

create-saemref-user:
  user.present:
    - name: {{ saemref.instance.user }}

legacy cleanup:
  pkg.removed:
    - pkgs:
      - cubicweb-saem-ref
      - cubicweb
      - python-logilab-common
      - python-logilab-mtconverter
      - python-rql
      - python-yams
      - python-logilab-database
      - python-passlib
      - python-twisted-web
      - python-markdown
      - pytz
      - uwsgi
      - uwsgi-plugin-python

venv:
  virtualenv.managed:
    - name: /home/{{ saemref.instance.user }}/venv
    - system_site_packages: false
    - user: {{ saemref.instance.user }}
    - require:
      - pkg: legacy cleanup

  pip.installed:
    - name: pip
    - upgrade: true
    - bin_env: /home/{{ saemref.instance.user }}/venv
    - user: {{ saemref.instance.user }}
    - require:
      - virtualenv: venv

cubicweb in venv:
  pip.installed:
    - name: cubicweb
    - upgrade: true
    - bin_env: /home/{{ saemref.instance.user }}/venv
    - user: {{ saemref.instance.user }}
    - require:
      - virtualenv: venv

{% if saemref.versions.saemref -%}
  {% set saemref_pkgname = "cubicweb-saem_ref == {}".format(saemref.versions.saemref) -%}
{% else -%}
  {% set saemref_pkgname = "cubicweb-saem_ref" -%}
{% endif -%}
cubicweb-saem_ref:
  pip.installed:
    - name: {{ saemref_pkgname }}
    - upgrade: true
    - user: {{ saemref.instance.user }}
    - bin_env: /home/{{ saemref.instance.user }}/venv
    - require:
      - pip: cubicweb in venv
      - user: {{ saemref.instance.user }}
      - virtualenv: venv

{% if saemref.instance.test_mode -%}
{% for fname in ['languages.csv', 'mime_types.csv'] %}
{{ ['/home', saemref.instance.user, 'venv', 'lib', 'python2.7', 'site-packages', 'cubicweb_seda', 'migration', 'data', fname]|join('/') }}:
  file.managed:
    - source: salt://saemref/files/test/{{ fname }}
    - user: {{ saemref.instance.user }}
    - show_changes: false
    - require:
      - pip: cubicweb-saem_ref
{% endfor %}
{%- endif %}

cubicweb-create:
  cmd.run:
    - name: /home/{{ saemref.instance.user }}/venv/bin/cubicweb-ctl create --no-db-create -a saem_ref {{ saemref.instance.name }}
    - creates: /home/{{ saemref.instance.user }}/etc/cubicweb.d/{{ saemref.instance.name }}
    - runas: {{ saemref.instance.user }}
    - env:
        CW_MODE: user
    - require:
        - pkg: cube-packages
        - user: {{ saemref.instance.user }}

{% if saemref.instance.wsgi %}

gunicorn in venv:
  pip.installed:
    - pkgs:
      - gunicorn
      - futures
    - upgrade: true
    - bin_env: /home/{{ saemref.instance.user }}/venv
    - user: {{ saemref.instance.user }}
    - require:
      - virtualenv: venv

{% if grains['os_family'] == 'RedHat' %}
crontabs installed:
  pkg.installed:
    - name: crontabs
{% endif %}
{% endif %}
