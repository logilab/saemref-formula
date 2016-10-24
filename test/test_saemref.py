# coding: utf-8
from __future__ import unicode_literals

import re

import pytest

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


def test_package_saem_ref(Package):
    cube = Package("cubicweb-saem-ref")
    assert cube.is_installed
    assert cube.version.startswith("0.13.0")


def test_package_cubicweb(Package, SystemInfo):
    if SystemInfo.distribution == "centos":
        name = "cubicweb"
    else:  # Debian
        name = "cubicweb-server"

    cubicweb = Package(name)
    assert cubicweb.is_installed
    assert cubicweb.version.startswith("3.23")
    assert map(int, cubicweb.version.split('.')) >= [3, 23, 1]


@pytest.mark.parametrize("name, version", [
    ("saem_ref", "0.13.0"),
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
        "cubicweb in venv",
    ]),
    ("saemref.supervisor", [
        # Has 'ignore_installed: true', so would re-run unconditionally.
        "cubicweb in venv",
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
def test_saemref_running(Process, Service, Socket, Command, is_centos6, supervisor_service_name):
    assert Service(supervisor_service_name).is_enabled

    supervisord = Process.get(comm="supervisord")

    if is_centos6:
        assert supervisord.user == "saemref"
        assert supervisord.group == "saemref"
    else:
        assert supervisord.user == "root"
        assert supervisord.group == "root"

    cubicweb = Process.get(ppid=supervisord.pid)

    if not is_centos6:
        assert cubicweb.comm == "uwsgi"
        # Should have 2 worker process with 8 thread each and 1 http proccess with one thread
        child_threads = sorted([c.nlwp for c in Process.filter(ppid=cubicweb.pid)])
        assert child_threads == [1, 8, 8]
    else:
        # twisted
        assert cubicweb.comm == "cubicweb-ctl"

    assert cubicweb.user == "saemref"
    assert cubicweb.group == "saemref"

    assert Socket("tcp://0.0.0.0:8080").is_listening

    html = Command.check_output("curl http://localhost:8080")
    assert "<title>accueil (Référentiel SAEM)</title>" in html


def test_saemref_sync_source_cronjob(Command):
    jobs = Command.check_output("crontab -u saemref -l").splitlines()
    assert '* */1 * * * CW_MODE=user cubicweb-ctl source-sync --loglevel error saemref' in jobs
