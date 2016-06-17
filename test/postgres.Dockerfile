FROM postgres:9.4

RUN apt-get -qqy update && apt-get -qqy install postgresql-plpython-9.4
