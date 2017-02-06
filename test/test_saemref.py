# coding: utf-8
from __future__ import unicode_literals

from os import path
import re

import pytest


DATA_DIR = path.join(path.abspath(path.dirname(__file__)), "data")


wait_supervisord_started = pytest.mark.usefixtures("_wait_supervisord_started")
wait_saemref_started = pytest.mark.usefixtures("_wait_saemref_started")


def test_package_postgresclient(Package, SystemInfo):
    if SystemInfo.distribution == "centos":
        name = "postgresql94"
    else:  # Debian
        name = "postgresql-client"

    pkg = Package(name)
    assert pkg.is_installed
    assert pkg.version.startswith("9.4")


def test_pip_packages(PipPackage):
    packages = PipPackage.get_packages(pip_path='/home/saemref/venv/bin/pip')
    assert packages['cubicweb']['version'].startswith("3.24")
    assert map(int, packages['cubicweb']['version'].split('.')) >= [3, 24, 5]
    assert packages['cubicweb-saem-ref']['version'].startswith("0.14.2")


@pytest.mark.parametrize("name, version", [
    ("cubicweb_saem_ref", "0.14.2"),
])
def test_devinstall(Command, name, version):
    cmd = "/home/saemref/venv/bin/cubicweb-ctl list cubes"
    out = Command.check_output(cmd)
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
def test_idempotence(Salt, state, exclude):
    result = Salt("state.sls", state)
    for item in result.values():
        assert item["result"] is True, item
        if item["__id__"] in exclude:
            continue
        assert item["changes"] == {}


@wait_saemref_started
def test_saemref_running(Process, Service, Socket, Command, supervisor_service_name):
    assert Service(supervisor_service_name).is_enabled

    supervisord = Process.get(comm="supervisord")

    assert supervisord.user == "root"
    assert supervisord.group == "root"

    cubicweb = Process.get(ppid=supervisord.pid)

    assert cubicweb.user == "saemref"
    assert cubicweb.group == "saemref"

    assert Socket("tcp://0.0.0.0:8080").is_listening

    html = Command.check_output("curl http://localhost:8080")
    assert "<title>accueil (Référentiel SAEM)</title>" in html

    assert cubicweb.comm == "uwsgi"
    # Should have 2 worker process with 8 thread each and 1 http proccess with one thread
    child_threads = sorted([c.nlwp for c in Process.filter(ppid=cubicweb.pid)])
    assert child_threads == [1, 8, 8]


def test_saemref_sync_source_cronjob(Command):
    jobs = Command.check_output("crontab -u saemref -l")
    assert 'cubicweb-ctl source-sync --loglevel error saemref' in jobs


@wait_saemref_started
@pytest.mark.docker_addopts("-v", "{0}:/data".format(DATA_DIR))
@pytest.mark.destructive
def test_saemref_client(Command):
    # execute c-c shell file to create NAA, organization and user
    output = cc_shell(Command, 'configure_instance.py')
    # retrieve the generated secret token
    token_secret = output.splitlines()[-1]
    # and generate file containing authentication information
    output = Command.check_output(
        '''cat <<EOF > cubicweb.yaml
id: token-user
secret: {}
EOF'''.format(token_secret))

    # test skos-download command
    output = Command.check_output(
        'python -m saemref_client skos-download -v http://localhost:8080 '
        '25651/v1 -o /tmp/skos-download/')
    folder_content = Command.check_output('ls /tmp/skos-download/25651-v1/*.xml')
    assert folder_content, \
        '{}\n\nFolder content: {}'.format(output, folder_content)

    # test eac-upload command
    output = Command.check_output(
        'python -m saemref_client eac-upload http://localhost:8080 '
        '/data/eac.xml')
    assert 'ark' in output

    # eac-download command
    cc_shell(Command, 'publish_authority_records.py')
    Command.check_output('mkdir /tmp/eac-download/')
    output = Command.check_output(
        'python -m saemref_client eac-download http://localhost:8080 '
        ' -o /tmp/eac-download/')
    folder_content = Command.check_output('ls /tmp/eac-download/*.xml')
    assert folder_content, \
        '{}\n\nFolder content: {}'.format(output, folder_content)


def cc_shell(Command, script_name):
    return Command.check_output(
        'CW_INSTANCES_DIR=/home/saemref/etc/cubicweb.d '
        '/home/saemref/venv/bin/cubicweb-ctl shell saemref '
        '/data/%s', script_name)
