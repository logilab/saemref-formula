import subprocess
import pytest
import testinfra
import time


@pytest.fixture
def TestinfraBackend(request):
    # Override the TestinfraBackend fixture,
    # all testinfra fixtures (i.e. modules) depend on it.

    cmd = ["docker", "run", "-d"]
    if "centos7" in request.param:
        # Systemd require privileged container
        cmd.append("--privileged")
    cmd.append(request.param)
    docker_id = subprocess.check_output(cmd).strip()

    def teardown():
        subprocess.check_output(["docker", "rm", "-f", docker_id])

    # Destroy the container at the end of the fixture life
    request.addfinalizer(teardown)

    # Return a dynamic created backend
    return testinfra.get_backend("docker://" + docker_id)


def pytest_addoption(parser):
    parser.addoption(
        "--docker-image", action="store", dest="docker_image",
        help="docker image(s) to test")


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
            scope = "session"

        metafunc.parametrize(
            "TestinfraBackend", images.split(","), indirect=True, scope=scope)


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
