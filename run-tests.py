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


image_option = click.argument("image", type=click.Choice(["centos7", "jessie"]))
salt_option = click.option('--salt', is_flag=True, help="Run salt highstate")


@click.group()
def cli():
    pass


@cli.command(help="Build a container")
@image_option
@salt_option
@click.option('--tag', default=None, help="Custom tag name for the built docker image")
@click.option('--file-root', type=click.Path(exists=True), default='test/salt')
@click.option('--pillar-root', type=click.Path(exists=True), default='test/pillar')
@click.option('--log-level', type=click.Choice(['debug', 'info', 'warning', 'error']),
              default='info')
def build(image, salt, tag, file_root, pillar_root, log_level):
    dockerfile = "test/{0}.Dockerfile".format(image)
    if salt:
        dockerfile_content = open(dockerfile, "r").read()
        dockerfile_content += (
            "\n"
            "ADD test/minion.conf /etc/salt/minion.d/minion.conf\n"
            "ADD %(file_root)s /srv/salt\n"
            "ADD %(pillar_root)s /srv/pillar\n"
            "ADD %(formula)s /srv/formula/%(formula)s\n"
            "RUN salt-call --hard-crash --retcode-passthrough -l %(log_level)s state.highstate\n"
        ) % {
            "file_root": file_root,
            "pillar_root": pillar_root,
            "formula": _formula,
            "log_level": log_level,
        }
        dockerfile = os.path.join("test", "{0}_salted.Dockerfile".format(image))
        with open(dockerfile, "wb") as fd:
            fd.write(dockerfile_content.encode())

    if tag is None:
        tag = get_tag(image, salt)
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
        ctx.invoke(build, image=image, salt=True, log_level='debug')
    postgres_tag = get_tag("postgres", False)
    if not image_exists(postgres_tag):
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

    if image in ("centos7", "jessie"):
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
