import subprocess
import pytest
import testinfra
import time


@pytest.fixture
def TestinfraBackend(pytestconfig, request):
    # Override the TestinfraBackend fixture,
    # all testinfra fixtures (i.e. modules) depend on it.

    cmd = ["docker", "run", "-d"]
    if "centos7" in request.param:
        # Systemd require privileged container
        cmd.append("--privileged")

    postgres_id = None
    if request.scope == "function":
        if hasattr(request.function, "use_postgres"):
            postgres_id = subprocess.check_output([
                "docker", "run", "-d", pytestconfig.getoption('postgres_image'),
            ]).strip()
            cmd.extend(["--link", "{0}:postgres".format(postgres_id)])

        if hasattr(request.function, "docker_addopts"):
            cmd.extend(list(request.function.docker_addopts.args))

    cmd.append(request.param)
    docker_id = subprocess.check_output(cmd).strip()

    def teardown():
        subprocess.check_output(["docker", "rm", "-f", docker_id])
        if postgres_id is not None:
            subprocess.check_output(["docker", "rm", "-f", postgres_id])

    # Destroy the container at the end of the fixture life
    request.addfinalizer(teardown)

    # Return a dynamic created backend
    return testinfra.get_backend("docker://" + docker_id)


def pytest_addoption(parser):
    parser.addoption(
        "--docker-image", action="store", dest="docker_image",
        help="docker image(s) to test")
    parser.addoption(
        "--postgres-image", action="store", dest="postgres_image",
        help="postgres image to use in postgres tests")
    parser.addoption(
        "--upgrade-revision", action="store",
        help="List of hg revision to test against (use 'master' for latest public changeset)")


def pytest_generate_tests(metafunc):
    if "TestinfraBackend" in metafunc.fixturenames:

        images = metafunc.config.option.docker_image
        if not images:
            pytest.skip("Missing docker image")
            return

        # If the test has a destructive marker, we scope TestinfraBackend
        # at function level (i.e. executing for each test). If not we scope
        # at session level (i.e. all tests will share the same container)
        if getattr(metafunc.function, "destructive", None) is not None:
            scope = "function"
        else:
            for marker in ("use_postgres", "docker_addopts"):
                if hasattr(metafunc.function, marker):
                    raise RuntimeError(
                        "You cannot use %s marker on a non destructive test" % (marker,))
            scope = "session"

        metafunc.parametrize(
            "TestinfraBackend", images.split(","), indirect=True, scope=scope)
    if 'saem_ref_upgrade_revision' in metafunc.fixturenames:
        if not metafunc.config.option.upgrade_revision:
            pytest.skip()
        else:
            metafunc.parametrize('saem_ref_upgrade_revision', [metafunc.config.option.upgrade_revision])


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
