{% if grains['os_family'] == 'Debian' %}

{% elif grains['os_family'] == 'RedHat' %}

include:
  - epel
  - postgres.upstream

logilab_extranet:
  pkgrepo.managed:
    - humanname: Logilab extranet BRDX $releasever $basearch
    - baseurl: https://extranet.logilab.fr/static/BRDX/rpms/epel-$releasever-$basearch
    - gpgcheck: 0
{% endif %}
