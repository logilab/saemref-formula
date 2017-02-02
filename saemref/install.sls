# -*- coding: utf-8 -*-
{% from "saemref/map.jinja" import saemref with context %}

include:
{% if grains['os_family'] == 'RedHat' %}
  - epel
  - postgres.upstream
{% endif %}


cube-packages:
  pkg.latest:
    - pkgs:
    {% if grains['os_family'] == 'Debian' %}
      - postgresql-client
      - graphviz
      - python-pip
      - python-all-dev
      - libgecode-dev
    {% else %}{# RedHat #}
      - postgresql94
      - graphviz-gd
      - python2-pip
      - python-devel
      - gecode-devel
    {% endif %}
      - gettext
      - python-virtualenv
      - python-lxml
      - python-psycopg2
  pip.installed:
    - name: setuptools
    - ignore_installed: true

create-saemref-user:
  user.present:
    - name: {{ saemref.instance.user }}

venv:
  virtualenv.managed:
    - name: /home/{{ saemref.instance.user }}/venv
    - system_site_packages: true
    - user: {{ saemref.instance.user }}

cubicweb in venv:
  pip.installed:
    - name: cubicweb
    - bin_env: /home/{{ saemref.instance.user }}/venv
    - user: {{ saemref.instance.user }}
    - require:
      - virtualenv: venv

cubicweb-saem_ref:
  pip.installed:
    - name: cubicweb-saem_ref
    - user: {{ saemref.instance.user }}
    - bin_env: /home/{{ saemref.instance.user }}/venv
    - require:
      - pip: cubicweb in venv
      - user: {{ saemref.instance.user }}
      - virtualenv: venv
  pkg.removed:
    - pkgs:
      - cubicweb

{% if saemref.install.dev %}

dev dependencies:
  pkg.installed:
    - pkgs:
      - mercurial

cubicweb-saem_ref from hg:
  pip.installed:
    - name: hg+http://hg.logilab.org/review/cubes/saem_ref#egg=cubicweb-saem_ref
    - user: {{ saemref.instance.user }}
    - bin_env: /home/{{ saemref.instance.user }}/venv
    - require:
      - pkg: dev dependencies
      - pip: cubicweb in venv
      - user: {{ saemref.instance.user }}
      - virtualenv: venv

{% endif %}

{% if saemref.instance.test_mode -%}
{% for fname in ['languages.csv', 'mime_types.csv'] %}
{{ ['/home', saemref.instance.user, 'venv', 'share', 'cubicweb', 'cubes', 'seda', 'migration', 'data', fname]|join('/') }}:
  file.managed:
    - source: salt://saemref/files/test/{{ fname }}
    - user: {{ saemref.instance.user }}
    - show_changes: false
{% endfor %}
{%- endif %}

cubicweb-create:
  cmd.run:
    - name: /home/{{ saemref.instance.user }}/venv/bin/cubicweb-ctl create --no-db-create -a saem_ref {{ saemref.instance.name }}
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
      - uwsgi
      - uwsgi-plugin-python
    {% if grains['os_family'] == 'Debian' %}
    - require:
      - pkgrepo: backports
    {% else %}{# RedHat #}
      - crontabs
    {% endif %}

{% endif %}
