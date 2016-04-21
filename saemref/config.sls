{% from "saemref/map.jinja" import saemref with context %}

include:
  - saemref.install

cubicweb-config:
  file.managed:
    - name: /home/{{ saemref.instance.user }}/etc/cubicweb.d/{{ saemref.instance.name }}/sources
    - source: salt://saemref/files/sources.j2
    - template: jinja

{% if saemref.instance.base_url %}
/home/{{ saemref.instance.user }}/etc/cubicweb.d/saemref/all-in-one.conf:
  file.replace:
    - pattern: "^#? *base-url *=(.*)$"
    - repl: base-url={{ saemref.instance.base_url }}
    - append_if_not_found: true
{% endif %}
