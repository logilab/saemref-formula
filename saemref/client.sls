saemref-client:
  pip.installed:
    - name: git+https://framagit.org/saemproject/saem-client.git#egg=saemref-client
    - require:
      - pkg: pip-setuptools
