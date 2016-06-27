# -*- coding: utf-8 -*-
{% from "saemref/map.jinja" import saemref with context %}
{% if grains['os_family'] == 'Debian' %}

logilab-public-acceptance:
  pkgrepo.managed:
    - name: deb http://download.logilab.org/acceptance {{ grains['oscodename'] }}/
    - file: /etc/apt/sources.list.d/logilab-public-acceptance.list
    - human_name: Logilab acceptance public Debian repository
    - gpgcheck: 1
    - key_url: https://www.logilab.fr/logilab-dists-key.asc

{% if saemref.instance.wsgi %}
# Needed for python-wsgicors
backports:
  pkgrepo.managed:
    - name: deb http://httpredir.debian.org/debian {{ grains['oscodename'] }}-backports contrib non-free main
    - file: /etc/apt/sources.list.d/backports.list

# Needed for python-pyramid-multiauth
logilab-backports:
  pkgrepo.managed:
    - name: deb http://download.logilab.org/backports/dists/ {{ grains['oscodename'] }}/
    - file: /etc/apt/sources.list.d/logilab-backports.list
    - gpgcheck: 1
    - key_url: https://www.logilab.fr/logilab-dists-key.asc
{% endif %}

{% elif grains['os_family'] == 'RedHat' %}

logilab_extranet:
  pkgrepo.managed:
    - humanname: Logilab extranet BRDX $releasever $basearch
    - baseurl: https://extranet.logilab.fr/static/BRDX/rpms/epel-$releasever-$basearch
    - gpgcheck: 0
{% endif %}
