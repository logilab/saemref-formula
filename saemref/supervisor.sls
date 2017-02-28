{% from "saemref/map.jinja" import saemref, is_docker_build with context %}

include:
  - saemref.install

supervisor:
  pkg:
    - installed

{{ saemref.supervisor_conffile }}:
  file.managed:
    - source: salt://saemref/files/saemref-supervisor.conf
    - template: jinja
    {% if grains['os_family'] != 'Debian' %}
    - user: {{ saemref.instance.user }}
    {% endif %}
    - makedirs: true
    - require:
      - pkg: supervisor

supervisor-service-running:
{% if is_docker_build %}
{#
Salt fail to enable a systemd service if systemd is not running (during the
docker build phase) This is a workaround.
#}
  cmd.run:
    - name: systemctl enable {{ saemref.supervisor_service_name }}
{% else %}
  service.running:
    - name: {{ saemref.supervisor_service_name }}
    - enable: true
{% endif %}
