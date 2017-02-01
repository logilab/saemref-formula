{% from "saemref/map.jinja" import saemref, supervisor_confdir, supervisor_conffile, supervisor_service_name, is_docker_build with context %}

include:
  - saemref.install

supervisor:
  pkg:
    - installed

supervisor_confdir:
  file.directory:
    - name: {{ supervisor_confdir }}
    - require:
      - pkg: supervisor

{{ supervisor_conffile }}:
  file.managed:
    - source: salt://saemref/files/saemref-supervisor.conf
    - template: jinja
    {% if grains['os_family'] != 'Debian' %}
    - user: {{ saemref.instance.user }}
    {% endif %}
    - require:
      - file: supervisor_confdir

supervisor-service-running:
{% if is_docker_build %}
{#
Salt fail to enable a systemd service if systemd is not running (during the
docker build phase) This is a workaround.
#}
  cmd.run:
    - name: systemctl enable {{ supervisor_service_name }}
{% else %}
  service.running:
    - name: {{ supervisor_service_name }}
    - enable: true
{% endif %}
