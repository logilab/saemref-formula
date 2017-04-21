# coding: utf-8

import os

import pytest

DUMPS_DIR = os.path.join(os.path.abspath(os.path.dirname(__file__)), "dumps")
DUMPS = [fname for fname in os.listdir(DUMPS_DIR) if fname.endswith(".tar.gz")]


@pytest.mark.parametrize("dump", DUMPS)
@pytest.mark.docker_addopts("-v", "{0}:/dumps".format(DUMPS_DIR))
@pytest.mark.use_postgres
@pytest.mark.destructive
def test_migration(host, dump, saem_ref_upgrade_revision):
    run = host.check_output
    db_host = host.salt("environ.get", "POSTGRES_PORT_5432_TCP_ADDR")
    db_port = host.salt("environ.get", "POSTGRES_PORT_5432_TCP_PORT")
    config = "/home/saemref/etc/cubicweb.d/saemref/sources"
    run("sed -ri %s %s", "s@^db-driver=.*$@db-driver=postgres@", config)
    run("sed -ri %s %s", "s@^db-user=.*$@db-user=postgres@", config)
    run("sed -ri %s %s", "s@^db-name=.*$@db-name=saemref@", config)
    run("sed -ri %s %s", "s@^db-host=.*$@db-host={0}@".format(db_host), config)
    run("sed -ri %s %s", "s@^db-port=.*$@db-port={0}@".format(db_port), config)
    run("createdb -h {0} -p {1} -U postgres saemref".format(db_host, db_port))
    run("yum install -y mercurial python-pip")
    # Weird bug with backports.ssl_match_hostname
    run("pip install -I setuptools")
    if saem_ref_upgrade_revision == "master":
        pkg = "hg+http://hg.logilab.org/master/cubes/saem_ref@default#egg=cubicweb-saem-ref"
    else:
        pkg = "hg+http://hg.logilab.org/review/cubes/saem_ref@{0}#egg=cubicweb-saem-ref".format(
            saem_ref_upgrade_revision)
    run("pip install %s", pkg)
    run("su - saemref -c 'CW_MODE=user cubicweb-ctl db-restore saemref /dumps/{0}'".format(dump))
    out = host.run("su - saemref -c 'CW_MODE=user cubicweb-ctl upgrade -v 0 --force --backup-db=n saemref'")
    # upgrade exit 0 even if a migration failed
    assert out.rc == 0
    assert "-> instance migrated." in out.stdout, "STDOUT:\n\n%s\n\nSTDERR:\n\n%s" % (out.stdout, out.stderr)
