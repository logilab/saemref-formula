#!/usr/bin/env python

import sys
import os
import argparse
import subprocess

BASEDIR = os.path.abspath(os.path.dirname(__file__))

_formula = "saemref"
_images = ["centos6"]


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


def _build(image, salt=False):
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
            b"RUN salt-call -l debug state.highstate\n"
        ).format(_formula)
        dockerfile = os.path.join("test", "{0}_salted.Dockerfile".format(image))
        with open(dockerfile, "wb") as fd:
            fd.write(dockerfile_content)
    subprocess.check_call([
        "docker", "build", "-t", tag, "-f", dockerfile, ".",
    ])


def build(args, remain):
    _build(args.image, args.salt)


def test(args, remain):
    tag = get_tag(args.image, True)
    _build(args.image, True)

    import pytest
    return pytest.main(["--docker-image", tag] + remain)


def dev(args, remain):
    tag = get_tag(args.image, args.salt)
    if not image_exists(tag):
        _build(args.image, args.salt)
    subprocess.call([
        "docker", "run", "--rm", "-it",
        "-v", "{0}/test/minion.conf:/etc/salt/minion.d/minion.conf".format(BASEDIR),
        "-v", "{0}/test/salt:/srv/salt".format(BASEDIR),
        "-v", "{0}/test/pillar:/srv/pillar".format(BASEDIR),
        "-v", "{0}/{1}:/srv/formula/{1}".format(BASEDIR, _formula),
        tag, "/bin/bash",
    ])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test {0} formula in docker".format(_formula))
    subparsers = parser.add_subparsers(help="sub-command help")

    parser_build = subparsers.add_parser("build", help="build images")
    parser_build.add_argument("image", choices=_images)
    parser_build.add_argument("--salt", action="store_true")
    parser_build.set_defaults(func=build)

    parser_dev = subparsers.add_parser("dev", help="drop a shell in dev container")
    parser_dev.add_argument("image", choices=_images)
    parser_dev.add_argument("--salt", action="store_true")
    parser_dev.set_defaults(func=dev)

    parser_test = subparsers.add_parser("test", help="provision a container and run tests on it")
    parser_test.add_argument("image", choices=_images)
    parser_test.set_defaults(func=test)

    args, remain = parser.parse_known_args()
    sys.exit(args.func(args, remain))
