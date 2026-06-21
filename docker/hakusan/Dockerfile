FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu20.04

ARG DEBIAN_FRONTEND=noninteractive
ARG CONDA_ENV=SG_Nav

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    bzip2 \
    ca-certificates \
    curl \
    git \
    gzip \
    libegl1 \
    libgl1 \
    libglib2.0-0 \
    libglvnd0 \
    libgomp1 \
    libopengl0 \
    libomp5 \
    libsm6 \
    libx11-6 \
    libxext6 \
    libxrender1 \
    openssh-client \
    wget \
    zstd \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-py39_24.5.0-0-Linux-x86_64.sh \
    && bash /tmp/miniconda.sh -b -p /opt/conda \
    && rm /tmp/miniconda.sh \
    && /opt/conda/bin/conda clean -ya

ENV PATH=/opt/conda/bin:/opt/conda/envs/${CONDA_ENV}/bin:${PATH}

COPY sg_nav_env.tar.gz /tmp/sg_nav_env.tar.gz
RUN mkdir -p /opt/conda/envs/${CONDA_ENV} \
    && tar -xzf /tmp/sg_nav_env.tar.gz -C /opt/conda/envs/${CONDA_ENV} \
    && /opt/conda/envs/${CONDA_ENV}/bin/conda-unpack \
    && rm /tmp/sg_nav_env.tar.gz \
    && /opt/conda/bin/conda clean -ya

COPY sg-nav-source.tar.gz /tmp/sg-nav-source.tar.gz
RUN mkdir -p /opt/sg-nav \
    && tar -xzf /tmp/sg-nav-source.tar.gz -C /opt/sg-nav \
    && rm /tmp/sg-nav-source.tar.gz \
    && mkdir -p /opt/sg-nav/data /opt/sg-nav/GLIP/MODEL /opt/sg-nav/.local/ollama-models \
    && chmod +x /opt/sg-nav/run_sg_nav.sh /opt/sg-nav/check_sg_nav_env.sh /opt/sg-nav/tools/check_sg_nav_env.py

ENV CONDA_ENV=${CONDA_ENV}
ENV CONDA_PREFIX=/opt/conda/envs/${CONDA_ENV}
ENV PYTHONPATH=/opt/sg-nav/habitat-lab:/opt/sg-nav/segment_anything:/opt/sg-nav/GLIP:/opt/sg-nav/GroundingDINO:/opt/sg-nav
ENV LD_LIBRARY_PATH=/opt/conda/envs/${CONDA_ENV}/lib:/opt/conda/envs/${CONDA_ENV}/lib/python3.9/site-packages/torch/lib:/usr/local/cuda/lib64
ENV PATH=/opt/sg-nav/.local/ollama/bin:/opt/conda/bin:/opt/conda/envs/${CONDA_ENV}/bin:${PATH}
ENV OLLAMA_HOST=127.0.0.1:11434
ENV OLLAMA_MODELS=/opt/sg-nav/.local/ollama-models
ENV SG_NAV_RUNTIME_DIR=/tmp/sg-nav-runtime
ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json

WORKDIR /opt/sg-nav
RUN printf '%s\n' '{"file_format_version":"1.0.0","ICD":{"library_path":"libEGL_nvidia.so.0"}}' \
    > /usr/share/glvnd/egl_vendor.d/10_nvidia.json
CMD ["./check_sg_nav_env.sh"]
