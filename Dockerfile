# This image needs to be built from the top level project directory.
# Typically:
#    $  docker build -f docs/development/docker/underworld2/Dockerfile .

# MAINTAINER https://github.com/underworldcode/
FROM longgangfan/ubuntu2004uwgeo  as base_runtime
# install runtime requirements
USER root
ENV PYVER=3.8
FROM base_runtime AS build_base
# install build requirements
RUN apt-get update -qq 
RUN DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
        build-essential \
	gfortran \
        python3-dev \
        swig \
        libxml2-dev
RUN PYTHONPATH= /usr/bin/pip3 install --no-cache-dir scons 
# setup further virtualenv to avoid double copying back previous packages (h5py,mpi4py,etc)
RUN /usr/bin/python3 -m virtualenv --system-site-packages --python=/usr/bin/python3 ${VIRTUAL_ENV}
WORKDIR /tmp
RUN git config --global http.postBuffer 524288000
RUN git clone --progress --verbose --single-branch --branch v2.11_release https://github.com/underworldcode/underworld2.git
WORKDIR /tmp/underworld2
# RUN git checkout v2.11_release
RUN PATH=/usr/local/bin:$PATH
RUN pip3 install --no-cache-dir -vvv .
# clone UWGeodynamics, install 
WORKDIR /tmp
RUN git config --global http.postBuffer 524288000
RUN git clone --progress --verbose  --single-branch --branch development https://github.com/underworldcode/UWGeodynamics.git
WORKDIR /tmp/UWGeodynamics
# RUN git checkout development
RUN pip3 install --no-cache-dir -vvv  .
RUN pip3 install -U badlands
FROM base_runtime
COPY --from=build_base ${VIRTUAL_ENV} ${VIRTUAL_ENV}
# Record Python packages, but only record system packages! 
# Not venv packages, which will be copied directly in.
RUN pip3 uninstall setuptools --yes
RUN PYTHONPATH= /usr/bin/pip3 freeze >/opt/requirements.txt
# Record manually install apt packages.
RUN apt-mark showmanual >/opt/installed.txt
# Copy in examples, tests, etc. 
ENV NB_WORK /home/longgangfan
COPY --from=build_base --chown=longgangfan:users /tmp/underworld2/docs/examples   $NB_WORK/Underworld/examples
COPY --from=build_base --chown=longgangfan:users /tmp/underworld2/docs/cheatsheet $NB_WORK/Underworld/cheatsheet
COPY --from=build_base --chown=longgangfan:users /tmp/underworld2/docs/user_guide $NB_WORK/Underworld/user_guide
COPY --from=build_base --chown=longgangfan:users /tmp/underworld2/docs/test       $NB_WORK/Underworld/test
COPY --from=build_base --chown=longgangfan:users /tmp/UWGeodynamics/docs/examples   $NB_WORK/UWGeodynamics/examples
COPY --from=build_base --chown=longgangfan:users /tmp/UWGeodynamics/docs/tutorials  $NB_WORK/UWGeodynamics/tutorials
COPY --from=build_base --chown=longgangfan:users /tmp/UWGeodynamics/docs/benchmarks $NB_WORK/UWGeodynamics/benchmarks
RUN  chown -R  longgangfan:users /home/longgangfan/workspace /home/longgangfan/UWGeodynamics /home/longgangfan/Underworld
RUN jupyter serverextension enable --sys-prefix jupyter_server_proxy
USER $NB_USER
WORKDIR $NB_WORK
