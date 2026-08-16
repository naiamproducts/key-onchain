FROM ubuntu:22.04

ARG SCARB_VERSION=2.15.1
ARG SNFORGE_VERSION=0.63.0

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/root/.local/bin:${PATH}"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install Scarb (Cairo toolchain)
RUN curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh -s -- -v ${SCARB_VERSION}

# Install Starknet Foundry (snforge + sncast)
RUN curl -L https://raw.githubusercontent.com/foundry-rs/starknet-foundry/master/scripts/install.sh | sh
RUN /root/.foundry/bin/snfoundryup -v ${SNFORGE_VERSION}

# Install starknet-devnet
RUN pip3 install --break-system-packages starknet-devnet 2>/dev/null || \
    pip3 install --break-system-packages starknet-devnet-rs 2>/dev/null || \
    echo "starknet-devnet will be installed via cargo"

# Install cargo if needed for starknet-devnet-rs
RUN which cargo || (curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    export PATH="/root/.cargo/bin:${PATH}")

# Set up environment
ENV PATH="/root/.local/bin:/root/.foundry/bin:/root/.cargo/bin:${PATH}"

WORKDIR /app

# Copy project files
COPY . .

# Make scripts executable
RUN chmod +x docker/scripts/*.sh 2>/dev/null || true

# Expose ports
# 5050: starknet-devnet RPC
# 8080: starknet-devnet gateway
EXPOSE 5050 8080

# Default command: run tests
CMD ["bash", "docker/scripts/run-tests.sh"]
