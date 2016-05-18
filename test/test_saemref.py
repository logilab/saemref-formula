# coding: utf-8
from __future__ import unicode_literals

import time
import pytest

wait_supervisord_started = pytest.mark.usefixtures("_wait_supervisord_started")
wait_saemref_started = pytest.mark.usefixtures("_wait_saemref_started")


@pytest.fixture
def _wait_supervisord_started(Service):
    for _ in range(10):
        if Service("supervisord").is_running:
            break
        time.sleep(1)
    else:
        raise RuntimeError("No running supervisord")


@pytest.fixture
def _wait_saemref_started(Command, _wait_supervisord_started, is_centos6):
    if is_centos6:
        cmd = "su - saemref -c 'supervisorctl status saemref'"
    else:
        cmd = "supervisorctl status saemref"
    for _ in range(20):
        status = Command.check_output(cmd).split()
        if status[1] == "RUNNING":
            break
        else:
            assert status[1] in ("STARTING", "BACKOFF")
        time.sleep(1)
    else:
        raise RuntimeError("No running saemref")


@pytest.fixture
def is_centos6(SystemInfo):
    return SystemInfo.distribution.lower() == "centos" and SystemInfo.release.startswith("6")


@pytest.mark.parametrize("name, version", [
    ("cubicweb", "3.22.2"),
    ("cubicweb-saem-ref", "0.11.1"),
])
def test_packages(Package, name, version):
    pkg = Package(name)
    assert pkg.is_installed
    assert pkg.version.startswith(version)


@wait_supervisord_started
@pytest.mark.parametrize("state, exclude", [
    # FIXME: Contain container IP...
    ("saemref", ["/home/saemref/etc/cubicweb.d/saemref/all-in-one.conf"]),
    ("saemref.supervisor", []),
])
@pytest.mark.destructive()
def test_idempotence(Salt, state, exclude):
    result = Salt("state.sls", state)
    for item in result.values():
        assert item["result"] is True

        if item["name"] in exclude:
            continue

        assert item["changes"] == {}

    # If we run twice, nothing must change
    result = Salt("state.sls", state)
    for _, item in result.items():
        assert item["result"] is True
        assert item["changes"] == {}


@wait_saemref_started
def test_saemref_running(Process, Service, Socket, Command, is_centos6):
    assert Service("supervisord").is_enabled

    supervisord = Process.get(comm="supervisord")

    if is_centos6:
        assert supervisord.user == "saemref"
        assert supervisord.group == "saemref"
    else:
        assert supervisord.user == "root"
        assert supervisord.group == "root"

    cubicweb = Process.get(ppid=supervisord.pid)
    assert cubicweb.comm == "cubicweb-ctl"
    assert cubicweb.user == "saemref"
    assert cubicweb.group == "saemref"

    assert Socket("tcp://0.0.0.0:8080").is_listening

    html = Command.check_output("curl http://localhost:8080")
    assert "<title>accueil (Référentiel SAEM)</title>" in html
