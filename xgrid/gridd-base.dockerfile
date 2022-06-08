FROM ubuntu:focal

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y -q \
    ca-certificates \
    curl \
    libsqlite3-dev \
    man \
    postgresql-client \
 && mandb

RUN echo ". /usr/share/bash-completion/bash_completion" >> ~/.bashrc

CMD ["bash"]
