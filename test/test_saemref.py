# coding: utf-8
from __future__ import unicode_literals

import json
from os import path
import re

import pytest


DATA_DIR = path.join(path.abspath(path.dirname(__file__)), "data")
EXPECTED_SAEM_VERSION = "0.17"


wait_supervisord_started = pytest.mark.usefixtures("_wait_supervisord_started")
wait_saemref_started = pytest.mark.usefixtures("_wait_saemref_started")


def test_package_postgresclient(host):
    if host.system_info.distribution == "centos":
        name = "postgresql94"
    else:  # Debian
        name = "postgresql-client"

    pkg = host.package(name)
    assert pkg.is_installed
    assert pkg.version.startswith("9.4")


def test_pip_packages(host):
    packages = host.pip_package.get_packages(
        pip_path='/home/saemref/venv/bin/pip')
    assert packages['cubicweb']['version'].startswith("3.25")
    assert map(int, packages['cubicweb']['version'].split('.')) >= [3, 25]
    assert packages['cubicweb-saem-ref']['version'].startswith(EXPECTED_SAEM_VERSION)


@pytest.mark.parametrize("name, version", [
    ("saem_ref", EXPECTED_SAEM_VERSION),
])
def test_devinstall(host, name, version):
    cmd = "/home/saemref/venv/bin/cubicweb-ctl list cubes"
    out = host.check_output(cmd)
    m = re.search(r'\* {0}( )+{1}'.format(name, version), out)
    assert m, out


@wait_supervisord_started
@pytest.mark.parametrize("state, exclude", [
    ("saemref", [
        # FIXME: Contain container IP...
        "/home/saemref/etc/cubicweb.d/saemref/all-in-one.conf",
        # Has 'ignore_installed: true', so would re-run unconditionally.
        "pip-setuptools",
    ]),
])
@pytest.mark.destructive()
def test_idempotence(host, state, exclude):
    result = host.salt("state.sls", state)
    for item in result.values():
        assert item["result"] is True, item
        if item["__id__"] in exclude:
            continue
        assert item["changes"] == {}


def test_pillars(host):
    base_url = host.salt("pillar.get", "saemref:lookup:instance:base_url")
    assert base_url.startswith('http://')
    assert base_url.endswith(':8080')
    pillars = host.salt("pillar.items")
    expected = {
        'admin': {'login': 'admin', 'pass': 'admin'},
        'db': {
            'driver': 'sqlite',
            'host': '',
            'name': '/home/saemref/saemref.db',
            'pass': 'saemref',
            'port': '',
            'user': 'saemref'},
        'install': {'dev': True},
        'instance': {
            'anonymous_password': 'anon',
            'anonymous_user': 'anon',
            'authtk_persistent_secret': 'Polichinelle2',
            'authtk_session_secret': 'Polichinelle1',
            'name': 'saemref',
            'base_url': base_url,
            'pool_size': 8,
            'port': 8080,
            'oai_port': 8081,
            'oai_threads': 8,
            'sessions_secret': 'Polichinelle',
            'test_mode': True,
            'user': 'saemref',
            'wsgi': True,
            'wsgi_threads': 8,
            'wsgi_workers': 2,
        }
    }
    assert pillars == {
        'postgres': {'version': 9.4},
        'saemref': {'lookup': expected}
    }
    host.salt("state.sls", "test_pillar")
    # /tmp/formula_pillars.json should be written by test_pillar state
    pillars = json.loads(host.file("/tmp/formula_pillars.json").content)
    pillars.pop('lookup')
    if host.system_info.distribution == "centos":
        expected.update(
            supervisor_conffile='/etc/supervisord.d/saemref.ini',
            supervisor_service_name='supervisord')
    else:  # Debian
        expected.update(
            supervisor_conffile='/etc/supervisor/conf.d/saemref.conf',
            supervisor_service_name='supervisor')
    assert pillars == expected


@wait_saemref_started
def test_saemref_running(host, supervisor_service_name):
    assert host.service(supervisor_service_name).is_enabled

    supervisord = host.process.get(comm="supervisord")

    assert supervisord.user == "root"
    assert supervisord.group == "root"

    childs = host.process.filter(ppid=supervisord.pid)
    # one cubicweb-ctl process to run looping task, one gunicorn process for the
    # web ui, and another for the oai access point
    assert sorted([(c.comm, c.user, c.group) for c in childs]) == [("cubicweb-ctl", "saemref", "saemref"),
                                                                   ("gunicorn", "saemref", "saemref"),
                                                                   ("gunicorn", "saemref", "saemref")]

    assert host.socket("tcp://0.0.0.0:8080").is_listening
    assert host.socket("tcp://0.0.0.0:8081").is_listening

    html = host.run("curl http://localhost:8080").stdout_bytes
    assert b"<title>accueil (Référentiel SAEM)</title>" in html
    xml = host.check_output("curl http://localhost:8081/oai")
    assert xml.startswith("<?xml ")


def test_saemref_sync_source_cronjob(host):
    jobs = host.check_output("crontab -u saemref -l")
    assert 'cubicweb-ctl source-sync --loglevel error saemref' in jobs


@wait_saemref_started
@pytest.mark.docker_addopts("-v", "{0}:/data".format(DATA_DIR))
@pytest.mark.destructive
def test_saemref_client(host):
    # execute c-c shell file to create NAA, organization and user
    output = cc_shell(host, 'configure_instance.py')
    # retrieve the generated secret token
    token_secret = output.splitlines()[-1]
    # and generate file containing authentication information
    output = host.check_output(
        '''cat <<EOF > cubicweb.yaml
id: token-user
secret: {}
EOF'''.format(token_secret))

    # test skos-download command
    output = host.check_output(
        'python -m saemref_client skos-download -v http://localhost:8080 '
        '25651/v1 -o /tmp/skos-download/')
    folder_content = host.check_output('ls /tmp/skos-download/25651-v1/*.xml')
    assert folder_content, \
        '{}\n\nFolder content: {}'.format(output, folder_content)

    # test eac-upload command
    output = host.check_output(
        'python -m saemref_client eac-upload http://localhost:8080 '
        '/data/eac.xml')
    assert 'ark' in output

    # eac-download command
    cc_shell(host, 'publish_authority_records.py')
    host.check_output('mkdir /tmp/eac-download/')
    output = host.check_output(
        'python -m saemref_client eac-download http://localhost:8080 '
        ' -o /tmp/eac-download/')
    folder_content = host.check_output('ls /tmp/eac-download/*.xml')
    assert folder_content, \
        '{}\n\nFolder content: {}'.format(output, folder_content)


def cc_shell(host, script_name):
    return host.check_output(
        'CW_INSTANCES_DIR=/home/saemref/etc/cubicweb.d '
        '/home/saemref/venv/bin/cubicweb-ctl shell saemref '
        '/data/%s', script_name)
