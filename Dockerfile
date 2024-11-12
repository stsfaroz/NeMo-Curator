# See https://github.com/rapidsai/ci-imgs for ARG options
# NeMo Curator requires Python 3.10, Ubuntu 22.04/20.04, and CUDA 12 (or above)
ARG CUDA_VER=12.5.1
ARG LINUX_VER=ubuntu22.04
ARG PYTHON_VER=3.10
ARG IMAGE_LABEL
ARG REPO_URL
ARG CURATOR_COMMIT

FROM rapidsai/ci-conda:cuda${CUDA_VER}-${LINUX_VER}-py${PYTHON_VER} as curator-update
# Needed to navigate to and pull the forked repository's changes
ARG REPO_URL
ARG CURATOR_COMMIT

# Clone the user's repository, find the relevant commit, and install everything we need
RUN bash -exu <<EOF
  mkdir -p /opt/NeMo-Curator
  cd /opt/NeMo-Curator
  git init
  git remote add origin $REPO_URL
  git fetch origin '+refs/pull/*/merge:refs/remotes/pull/*/merge'
  git checkout $CURATOR_COMMIT
EOF


FROM rapidsai/ci-conda:cuda${CUDA_VER}-${LINUX_VER}-py${PYTHON_VER}
LABEL "nemo.library"=${IMAGE_LABEL}
WORKDIR /opt

# Install the minimal libcu* libraries needed by NeMo Curator
RUN conda create -y --name curator -c conda-forge -c nvidia \
  python=3.10 \
  cuda-cudart \
  libcufft \
  libcublas \
  libcurand \
  libcusparse \
  libcusolver && \
  source activate curator && \
  pip install --upgrade cython pytest pip

RUN \
  --mount=type=bind,source=/opt/NeMo-Curator/nemo_curator/__init__.py,target=nemo_curator/__init__.py,from=curator-update \
  --mount=type=bind,source=/opt/NeMo-Curator/pyproject.toml,target=pyproject.toml,from=curator-update \
  source activate curator && \
  pip install ".[all]"

COPY --from=curator-update /opt/NeMo-Curator/ /opt/NeMo-Curator/

# Clone the user's repository, find the relevant commit, and install everything we need
RUN bash -exu <<EOF
  source activate curator
  cd /opt/NeMo-Curator/
  pip install --extra-index-url https://pypi.nvidia.com ".[all]"
EOF

ENV PATH /opt/conda/envs/curator/bin:$PATH
