ARG BASE_TAG=stable
FROM ghcr.io/ucsd-ets/datascience-notebook:$BASE_TAG

USER root

# tensorflow, pytorch stable versions
# https://pytorch.org/get-started/previous-versions/
# https://www.tensorflow.org/install/source#linux

# coerce rebuild in only this nteb

ARG LIBNVINFER=7.2.2 LIBNVINFER_MAJOR_VERSION=7 CUDA_VERSION=11.8

RUN apt-get update && \
  apt-get install -y \
  libtinfo5 build-essential && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Symbolic link for Stata 17 dependency on libncurses5
RUN ln -s libncurses.so.6 /usr/lib/x86_64-linux-gnu/libncurses.so.5

COPY run_jupyter.sh /
RUN chmod +x /run_jupyter.sh

COPY cudatoolkit_env_vars.sh cudnn_env_vars.sh tensorrt_env_vars.sh /etc/datahub-profile.d/
COPY activate.sh /tmp/activate.sh

RUN chmod 777 /etc/datahub-profile.d/*.sh /tmp/activate.sh

# CUDA 11 
# tf requirements: https://www.tensorflow.org/install/pip#linux
RUN mamba install \
  cudatoolkit=11.8 \
  nccl \
  -y && \
  fix-permissions $CONDA_DIR && \
  fix-permissions /home/$NB_USER && \
  mamba clean -a -y

RUN mamba install -c "nvidia/label/cuda-11.8.0" cuda-nvcc -y && \
  fix-permissions $CONDA_DIR && \
  fix-permissions /home/$NB_USER && \
  mamba clean -a -y

# install protobuf to avoid weird base type error. seems like if we don't then it'll be installed twice.
# https://github.com/spesmilo/electrum/issues/7825
# pip cache purge didnt work here for some reason.
RUN pip install --no-cache-dir protobuf==3.20.3

    # no purge required but no-cache-dir is used. pip purge will actually break the build here!

USER $NB_UID:$NB_GID
ENV PATH=${PATH}:/usr/local/nvidia/bin:/opt/conda/bin

#ENV CUDNN_PATH=/opt/conda/lib/python3.9/site-packages/nvidia/cudnn

# starts like this: /opt/conda/pkgs/cudnn-8.6.0.163-pypi_0 8.8.1.3-pypi_0/lib/:/opt/conda/pkgs/cudatoolkit-11.8.0-h37601d7_11/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64
# need to have the end result of running 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/conda/lib/python3.9/site-packages/nvidia/cudnn/lib'
# then the gpu can be detected via CLI.
#ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/opt/conda/lib/python3.9/site-packages/nvidia/cudnn/lib

# packages
RUN apt-get -y update && \
    apt-get install -y --no-install-recommends build-essential git nano rsync vim tree curl \
    wget unzip htop tmux xvfb patchelf ca-certificates bash-completion libjpeg-dev libpng-dev \
    ffmpeg cmake swig libssl-dev libcurl4-openssl-dev libopenmpi-dev python3-dev zlib1g-dev \
    qtbase5-dev qtdeclarative5-dev libglib2.0-0 libglu1-mesa-dev libgl1-mesa-dev libvulkan1 \
    libgl1-mesa-glx libosmesa6 libosmesa6-dev libglew-dev mesa-utils && \
    apt-get clean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir /root/.ssh

# environment variables
ENV MUJOCO_GL egl
ENV MS2_ASSET_DIR /root/data
ENV LD_LIBRARY_PATH /root/.mujoco/mujoco210/bin:${LD_LIBRARY_PATH}

# Do some CONDA/CUDA stuff
# Copy libdevice file to the required path
RUN mkdir -p $CONDA_DIR/lib/nvvm/libdevice && \
  cp $CONDA_DIR/lib/libdevice.10.bc $CONDA_DIR/lib/nvvm/libdevice/

RUN . /tmp/activate.sh


