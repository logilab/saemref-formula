/tmp/formula_pillars.json:
  file.managed:
    - contents:
      {% raw %}
      - '{% from "saemref/map.jinja" import saemref with context -%}'
      - '{{ saemref|json }}'
      {% endraw %}
    - template: jinja
