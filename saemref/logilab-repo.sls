{% if grains['os_family'] == 'Debian' %}

logilab-public-acceptance:
  pkgrepo.managed:
    - file: /etc/apt/sources.list.d/logilab-public-acceptance.list
    - human_name: Logilab acceptance public Debian repository
    - name: deb http://download.logilab.org/acceptance {{ grains['oscodename'] }}/
    - gpgcheck: 1
    - key_url: https://www.logilab.fr/logilab-dists-key.asc

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
