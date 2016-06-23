{% from "saemref/map.jinja" import saemref, supervisor_confdir, supervisor_conffile, supervisor_service_name, is_docker_build with context %}

include:
  - saemref.install

{% if grains['os_family'] == 'RedHat' and grains['osmajorrelease'] == '6' %}

python-pip:
  pkg:
    - installed

supervisor:
  pip.installed:
    - user: {{ saemref.instance.user }}
    - install_options:
      - "--user"
    - require:
      - user: {{ saemref.instance.user }}
      - pkg: python-pip

{% for fname in ('supervisorctl', 'supervisord') %}
/home/{{ saemref.instance.user }}/bin/{{ fname }}:
  file.symlink:
    - target: /home/{{ saemref.instance.user }}/.local/bin/{{ fname }}
    - user: {{ saemref.instance.user }}
    - makedirs: true
    - require:
      - pip: supervisor
{% endfor %}

supervisor_confdir:
  file.directory:
    - name: {{ supervisor_confdir }}
    - user: {{ saemref.instance.user }}
    - require:
      - user: {{ saemref.instance.user }}

/home/{{ saemref.instance.user }}/etc/supervisord.conf:
  file.managed:
    - source: salt://saemref/files/supervisord.conf
    - template: jinja
    - user: {{ saemref.instance.user }}


/etc/init.d/supervisord:
  file.managed:
    - source: salt://saemref/files/supervisord.init
    - template: jinja
    - mode: 755

{% else %}

supervisor:
  pkg:
    - installed

supervisor_confdir:
  file.directory:
    - name: {{ supervisor_confdir }}
    - require:
      - pkg: supervisor


{% endif %}


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
