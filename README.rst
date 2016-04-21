===============
saemref-formula
===============

A saltstack formula handling installation of `saem_ref`_.

Available states
================

.. contents::
    :local:

``saemref.install``
-------------------

Installs the saemref package from logilab repositories and create an instance.

``saemref.config``
------------------

Manage instance configuration files.

``saemref.supervisor``
----------------------

Install and manage `supervisor`_ configuration for the saemref installation.


Testing
=======

The script `run-test.py` can help to develop and test the formula using
`docker`_ and `testinfra`_.

The command ``./run-test.py dev centos6`` will build image from
``test/centos6.Dockerfile`` and span a shell in a new container with mounted
volumes from the host (so you can develop formula on the host and test it in
the container with ``salt-call``).

The command ``./run-test.py dev centos6 --salt`` is the same as above but will
provision the container (eg. calling ``salt-call state.highstate``)

The command ``./run-test.py test centos6`` built a provisioned image
(highstate) and run testinfra tests on it.

Note that you can add any parameters that testinfra (pytest) accept, for
instance ``./run-test.py test centos6 -k idempotence --pdb``.


.. _saem_ref: https://www.cubicweb.org/project/cubicweb-saem_ref
.. _supervisor: http://supervisord.org
.. _docker: https://www.docker.com/
.. _testinfra: https://testinfra.readthedocs.org/
