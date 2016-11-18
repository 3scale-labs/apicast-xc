FROM ubuntu:xenial

MAINTAINER David Ortiz López <dortiz@redhat.com>

# Install dependencies
ARG BUILD_DEPS="sudo curl wget vim unzip python-pip build-essential"
RUN apt-get update
RUN apt-get install ${BUILD_DEPS} -y

# Configure user
ARG USER_NAME=user
ENV USER_HOME="/home/${USER_NAME}" DEBIAN_FRONTEND=noninteractive
RUN adduser --disabled-password --home ${USER_HOME} --shell /bin/bash --gecos "" ${USER_NAME}
RUN echo "${USER_NAME} ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USER_NAME} \
 && chmod 0440 /etc/sudoers.d/${USER_NAME} \
 && passwd -d ${USER_NAME} \
 && chown -R ${USER_NAME}: ${USER_HOME}

WORKDIR ${USER_HOME}

# Install Redis
RUN wget http://download.redis.io/redis-stable.tar.gz \
  && tar xvzf redis-stable.tar.gz \
  && cd redis-stable \
  && make \
  && make install

# Install lua, luarocks and rocks
ARG LUA="luajit=2.1"
ARG PREFIX=${USER_HOME}
ARG BINDIR=${PREFIX}/bin
ENV PATH="${BINDIR}:${PATH}"
USER ${USER_NAME}
RUN pip install --install-option="--install-scripts=${BINDIR}" hererocks
RUN ${BINDIR}/hererocks ${PREFIX} -r^ --${LUA}
RUN ${BINDIR}/luarocks install luacheck \
 && ${BINDIR}/luarocks install busted \
 && ${BINDIR}/luarocks install luacov \
 && ${BINDIR}/luarocks install inspect

# Install XC
RUN mkdir -p ${USER_HOME}/app
COPY apicast_xc.rockspec app/
RUN cd ${USER_HOME}/app \
 && XC_VERSION=$(cat apicast_xc.rockspec | grep -o -P '\s*version\s*=\s*"(.[^"]*)"\s*$' | sed -e 's/.*\"\([^\"]*\)"\s*$/\1/') \
 && ln -s apicast_xc.rockspec apicast_xc-${XC_VERSION}.rockspec \
 && ${BINDIR}/luarocks build --only-deps apicast_xc-${XC_VERSION}.rockspec

COPY . app/

USER root
RUN chown -R ${USER_NAME}: ${USER_HOME}/app

USER ${USER_NAME}
WORKDIR ${USER_HOME}/app
CMD /bin/bash -l -c "script/test"
