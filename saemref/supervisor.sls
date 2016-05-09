{% from "saemref/map.jinja" import saemref, supervisor_confdir with context %}

include:
  - saemref.install

{% if grains['os_family'] == 'Debian' %}

supervisor:
  pkg:
    - installed

supervisor_confdir:
  file.directory:
    - name: {{ supervisor_confdir }}
    - require:
      - pkg: supervisor

{% elif grains['os_family'] == 'RedHat' %}

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

{% endif %}


{{ supervisor_confdir }}/saemref.conf:
  file.managed:
    - source: salt://saemref/files/saemref-supervisor.conf
    - template: jinja
    {% if grains['os_family'] != 'Debian' %}
    - user: {{ saemref.instance.user }}
    {% endif %}
    - require:
      - file: supervisor_confdir

supervisor-service-running:
  service.running:
    - name: supervisord
    - enable: true
