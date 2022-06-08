FROM gridd-base as gridd-alpha

COPY cache/grid-cli_*.deb /tmp
COPY cache/grid-daemon_*.deb /tmp

RUN dpkg --unpack /tmp/grid*.deb

RUN apt-get -f -y install

CMD ["gridd"]
