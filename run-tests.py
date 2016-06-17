#!/usr/bin/env python

import click
import os
import subprocess

BASEDIR = os.path.abspath(os.path.dirname(__file__))

_formula = "saemref"


def get_tag(image, salt=False):
    tag = "{0}-formula:{1}".format(_formula, image)
    if salt:
        return tag + "_salted"
    else:
        return tag


def image_exists(image):
    # docker image accept tags only in version >= 1.8...
    # so workaround with docker history
    rc = subprocess.call("docker history -q {0} > /dev/null".format(image), shell=True)
    if rc == 0:
        return True
    elif rc == 1:
        return False
    else:
        raise RuntimeError("Cannot test if image exists")


image_option = click.argument("image", type=click.Choice(["centos6", "centos7"]))
salt_option = click.option('--salt', is_flag=True, help="Run salt highstate")


@click.group()
def cli():
    pass


@cli.command(help="Build a container")
@image_option
@salt_option
def build(image, salt):
    dockerfile = "test/{0}.Dockerfile".format(image)
    tag = get_tag(image, salt)
    if salt:
        dockerfile_content = open(dockerfile, "rb").read()
        dockerfile_content += (
            b"\n"
            b"ADD test/minion.conf /etc/salt/minion.d/minion.conf\n"
            b"ADD test/salt /srv/salt\n"
            b"ADD test/pillar /srv/pillar\n"
            b"ADD {0} /srv/formula/{0}\n"
            b"RUN salt-call --hard-crash -l debug state.highstate\n"
        ).format(_formula)
        if image in ("centos7",):
            # Salt fail to enable a systemd service if systemd is not running
            # (during the docker build phase)
            # This is a workaround.
            dockerfile_content += b"RUN systemctl enable supervisord\n"
        dockerfile = os.path.join("test", "{0}_salted.Dockerfile".format(image))
        with open(dockerfile, "wb") as fd:
            fd.write(dockerfile_content)
    subprocess.check_call([
        "docker", "build", "-t", tag, "-f", dockerfile, ".",
    ])


@cli.command(
    help="Build a salted (highstate) container and run tests on it",
    context_settings={"allow_extra_args": True},
)
@click.pass_context
@image_option
def test(ctx, image):
    tag = get_tag(image, True)
    if not image_exists(tag):
        ctx.invoke(build, image=image, salt=True)
    postgres_tag = get_tag("postgres", False)
    if not image_exists(tag):
        ctx.invoke(build, image="postgres", salt=False)

    import pytest
    ctx.exit(pytest.main(["--docker-image", tag, "--postgres-image", postgres_tag] + ctx.args))


@cli.command(help="Run a container and spawn an interactive shell inside")
@click.pass_context
@image_option
@salt_option
def dev(ctx, image, salt):
    tag = get_tag(image, salt)
    if not image_exists(tag):
        ctx.invoke(build, image=image, salt=salt)
    cmd = [
        "docker", "run", "-d", "--hostname", image,
        "-v", "{0}/test/minion.conf:/etc/salt/minion.d/minion.conf".format(BASEDIR),
        "-v", "{0}/test/salt:/srv/salt".format(BASEDIR),
        "-v", "{0}/test/pillar:/srv/pillar".format(BASEDIR),
        "-v", "{0}/{1}:/srv/formula/{1}".format(BASEDIR, _formula),
    ]

    if image in ("centos7",):
        # Systemd require privileged container
        cmd.append("--privileged")
    cmd.append(tag)

    # Run the container default CMD as pid 1 (init system)
    docker_id = subprocess.check_output(cmd).strip()
    try:
        # Spawn a interactive shell in the container
        subprocess.call(["docker", "exec", "-it", docker_id, "/bin/bash"])
    finally:
        subprocess.call(["docker", "rm", "-f", docker_id])


if __name__ == "__main__":
    cli()
