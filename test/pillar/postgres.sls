postgres:
  lookup:
    use_upstream_repo: True
    version: 9.4
    {% if grains['os_family'] == 'RedHat' %}
    service: postgresql-9.4
    pkg: postgresql94-server
    pkg_client: postgresql94-client
    commands:
      initdb: service postgresql-9.4 initdb
    {% endif %}
  users:
    saemref:
      ensure: present
      superuser: True
