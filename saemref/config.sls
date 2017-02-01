{% from "saemref/map.jinja" import saemref with context %}

include:
  - saemref.install

{% for filename in ('sources', 'all-in-one.conf') %}
/home/{{ saemref.instance.user }}/etc/cubicweb.d/{{ saemref.instance.name }}/{{ filename }}:
  file.managed:
    - source: salt://saemref/files/{{ filename }}.j2
    - template: jinja
{% endfor %}

{% if saemref.instance.wsgi %}
/home/{{ saemref.instance.user }}/etc/cubicweb.d/{{ saemref.instance.name }}/pyramid.ini:
  file.managed:
    - source: salt://saemref/files/pyramid.ini
    - template: jinja
    - user: {{ saemref.instance.user }}
    - group: {{ saemref.instance.user }}

/home/{{ saemref.instance.user }}/etc/cubicweb.d/{{ saemref.instance.name }}/uwsgi.ini:
  file.managed:
    - source: salt://saemref/files/uwsgi.ini
    - template: jinja
    - user: {{ saemref.instance.user }}
    - group: {{ saemref.instance.user }}

# HINT: This file is managed by cubicweb package on debian (and missing on centos)
/etc/logrotate.d/cubicweb-ctl:
  file.managed:
    - source: salt://saemref/files/logrotate.conf
    - template: jinja

CW_MODE=user /home/{{ saemref.instance.user }}/venv/bin/cubicweb-ctl source-sync --loglevel error {{ saemref.instance.name }}:
  cron.present:
    - user: {{ saemref.instance.user }}
    - hour: "*/1"
{% endif %}
