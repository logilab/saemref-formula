import pytest


@pytest.mark.parametrize("name, version", [
    ("cubicweb", "3.22.2"),
    ("cubicweb-saem-ref", "0.10.2"),
])
def test_packages(Package, name, version):
    pkg = Package(name)
    assert pkg.is_installed
    assert pkg.version.startswith(version)


@pytest.mark.parametrize("state, exclude", [
    # FIXME: Contain container IP...
    ("saemref", ["/home/saemref/etc/cubicweb.d/saemref/all-in-one.conf"]),

    # FIXME: supervisor service is started here
    ("saemref.supervisor", ["supervisor"]),
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
