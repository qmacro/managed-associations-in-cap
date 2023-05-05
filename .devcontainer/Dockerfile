# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.187.0/containers/javascript-node/.devcontainer/base.Dockerfile

# [Choice] Node.js version: 18, 16, 14
ARG VARIANT="18-buster"
FROM mcr.microsoft.com/vscode/devcontainers/javascript-node:0-${VARIANT}

# Install extra tools for CAP development & deployment.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends curl jq miller entr

# Install bat - cat with wings
ARG BATVER=0.22.1
RUN curl -fsSLO "https://github.com/sharkdp/bat/releases/download/v$BATVER/bat-musl_${BATVER}_amd64.deb" \
  && dpkg -i "./bat-musl_${BATVER}_amd64.deb" \
  && rm "./bat-musl_${BATVER}_amd64.deb"

# Install SAP CAP SDK globally at 6.5.0
RUN su node -c "npm install -g @sap/cds-dk@6.5.0"
