{% from "saemref/map.jinja" import saemref with context %}

include:
  - saemref.install

{% for filename in ('sources', 'all-in-one.conf') %}
/home/{{ saemref.instance.user }}/etc/cubicweb.d/{{ saemref.instance.name }}/{{ filename }}:
  file.managed:
    - source: salt://saemref/files/{{ filename }}.j2
    - template: jinja
{% endfor %}
