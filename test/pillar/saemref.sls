saemref:
  instance:
    base_url: http://{{ grains['ipv4'][1] }}:8080
  db:
    driver: sqlite
    name: /home/saemref/saemref.db

postgres:
  version: 9.4
