FROM gridd-base as gridd-alpha

COPY cache/target/debian/grid-cli_*.deb /tmp
COPY cache/target/debian/grid-daemon_*.deb /tmp

RUN dpkg --unpack /tmp/grid*.deb

RUN apt-get -f -y install

CMD ["gridd"]
