saemref:
  instance:
    base_url: http://{{ grains['fqdn_ip4'][0] }}:8080
  db:
    driver: sqlite
    name: /home/saemref/saemref.db

postgres:
  version: 9.4
