saemref:
  instance:
    {% for ip in grains['ipv4'] -%}
    {% if ip != '127.0.0.1' -%}
    base_url: http://{{ ip }}:8080
    {% break %}
    {% endif %}
    {% endfor %}
    sessions_secret: Polichinelle
    authtk_session_secret: Polichinelle1
    authtk_persistent_secret: Polichinelle2
  db:
    driver: sqlite
    name: /home/saemref/saemref.db

postgres:
  version: 9.4
