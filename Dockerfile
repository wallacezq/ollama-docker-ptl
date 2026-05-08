# Stage 1: Build stage
FROM ubuntu:24.04 as build
COPY ./start.sh /llm/scripts/start.sh

# Stage 2: Runtime image
# Builds from Intel oneAPI base + pip install ipex-llm
# This ensures we always get the latest ipex-llm (including nightly Ollama updates)
FROM intel/oneapi-basekit:2025.3.2-0-devel-ubuntu24.04

COPY --from=build /llm/scripts /llm/scripts/

ARG http_proxy
ARG https_proxy
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG PIP_NO_CACHE_DIR=false

# Core environment variables
ENV TZ=Asia/Shanghai \
    PYTHONUNBUFFERED=1 \
    SYCL_CACHE_PERSISTENT=1 \
    SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1 \
    ZES_ENABLE_SYSMAN=1 \
    USE_XETLA=OFF \
    OLLAMA_HOST=0.0.0.0:11434 \
    OLLAMA_NUM_GPU=999 \
    OLLAMA_MODELS=/root/.ollama/models \
    OLLAMA_DEBUG=1

# ONEAPI_DEVICE_SELECTOR and OLLAMA_NUM_PARALLEL are NOT set here.
# Setting them to empty string breaks SYCL device detection.
# Pass them via docker run -e when needed (e.g., -e ONEAPI_DEVICE_SELECTOR=level_zero:0).
# start.sh will log them if present.

RUN set -eux && \
    chmod +x /llm/scripts/*.sh && \
    #
    # Configure Intel OneAPI and GPU repositories
    #wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | tee /usr/share/keyrings/intel-oneapi-archive-keyring.gpg > /dev/null && \
    #echo "deb [signed-by=/usr/share/keyrings/intel-oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | tee /etc/apt/sources.list.d/oneAPI.list && \
    #chmod 644 /usr/share/keyrings/intel-oneapi-archive-keyring.gpg && \
    #rm -f /etc/apt/sources.list.d/intel-graphics.list && \
    #wget -O- https://repositories.intel.com/graphics/intel-graphics.key | gpg --dearmor | tee /usr/share/keyrings/intel-graphics.gpg > /dev/null && \
    #echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/graphics/ubuntu jammy arc" | tee /etc/apt/sources.list.d/intel.gpu.jammy.list && \
    #chmod 644 /usr/share/keyrings/intel-graphics.gpg && \
    #
    # Install basic dependencies
    apt-get update && \
    apt-get install -y --no-install-recommends curl wget git sudo libunwind8-dev vim less gnupg gpg-agent software-properties-common && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    #
    # Install Python 3.11
    add-apt-repository -y ppa:kobuk-team/intel-graphics && \
    add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get install -y --no-install-recommends libze-intel-gpu1 libze1 intel-metrics-discovery intel-opencl-icd clinfo intel-gsc && \
    apt-get install -y --no-install-recommends python3.11 python3-pip python3.11-dev python3.11-distutils python3-wheel && \
    rm /usr/bin/python3 && ln -s /usr/bin/python3.11 /usr/bin/python3 && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    #
    # Remove conflicting packages
    apt-get remove -y libze-dev libze-intel-gpu1 || true && \
    #
    # Install Intel GPU Compute Runtime (24.52)
    mkdir -p /tmp/gpu && cd /tmp/gpu && \
    wget https://github.com/intel/intel-graphics-compiler/releases/download/v2.32.7/intel-igc-core-2_2.32.7+21184_amd64.deb && \
    wget https://github.com/intel/intel-graphics-compiler/releases/download/v2.32.7/intel-igc-opencl-2_2.32.7+21184_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/26.14.37833.4/intel-ocloc_26.14.37833.4-0_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/26.14.37833.4/intel-opencl-icd_26.14.37833.4-0_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/26.14.37833.4/libigdgmm12_22.9.0_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/26.14.37833.4/libze-intel-gpu1_26.14.37833.4-0_amd64.deb && \
    dpkg -i *.deb && rm -rf /tmp/gpu && \
    #
    # Install Level Zero Loader
    #mkdir /tmp/level-zero && cd /tmp/level-zero && \
    #wget https://github.com/oneapi-src/level-zero/releases/download/v1.28.2/level-zero_1.28.2+u24.04_amd64.deb && \
    #wget https://github.com/oneapi-src/level-zero/releases/download/v1.28.2/level-zero-devel_1.28.2+u24.04_amd64.deb && \
    #dpkg -i *.deb && rm -rf /tmp/level-zero && \
    #
    # Install pip and ipex-llm with Ollama support (Intel XPU wheels, no CUDA)
    #wget https://bootstrap.pypa.io/get-pip.py -O get-pip.py && \
    #python3 get-pip.py && rm get-pip.py && \
    #pip install --upgrade requests argparse urllib3 && \
    #pip install --pre --upgrade ipex-llm[cpp] --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/ && \    
    # Initialize Ollama binary
    #mkdir -p /llm/ollama && cd /llm/ollama && init-ollama && \
    #mkdir -p /llm/ollama && cd /llm/ollama && \
    #
    # Cleanup
    apt-get clean && rm -rf /var/lib/apt/lists/* /root/.cache/Cypress

    # Install pip and ipex-llm with Ollama support (Intel XPU wheels, no CUDA)    
RUN pip install --break-system-packages --upgrade requests argparse urllib3 && \
    pip install --pre --break-system-packages --upgrade ipex-llm[cpp] --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/ && \    
    # Initialize Ollama binary
    #mkdir -p /llm/ollama && cd /llm/ollama && init-ollama && \
    mkdir -p /llm/ollama && cd /llm/ollama && init-ollama

COPY start.sh /llm/ollama/start.sh
RUN chmod +x /llm/ollama/start.sh

WORKDIR /llm/ollama
ENTRYPOINT ["/llm/ollama/start.sh"]

