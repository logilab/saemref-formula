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


CW_MODE=user cubicweb-ctl source-sync --loglevel error {{ saemref.instance.name }}:
  cron.present:
    - user: {{ saemref.instance.user }}
    - hour: "*/1"
{% endif %}
