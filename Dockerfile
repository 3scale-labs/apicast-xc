FROM centos:7

MAINTAINER David Ortiz López <dortiz@redhat.com>

# Install dependencies
ARG BUILD_DEPS="sudo curl wget vim unzip python-pip make gcc sysvinit-tools"
RUN yum -y update \
  && yum -y install epel-release \
  && yum -y install ${BUILD_DEPS} \
  && yum -y autoremove \
  && yum -y clean all

# Configure user
ARG USER_NAME=user
ENV USER_HOME="/home/${USER_NAME}"
RUN adduser --home-dir ${USER_HOME} --shell /bin/bash ${USER_NAME}
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
RUN pip install --install-option="--install-scripts=${BINDIR}" hererocks \
  && chown -R ${USER_NAME}: ${BINDIR}
USER ${USER_NAME}
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
