# ---- Builder Stage ----
FROM alpine:latest AS builder

ARG TARGETOS
ARG TARGETARCH

RUN apk add --no-cache \
  go \
  curl \
  tar \
  jq \
  yq \
  coreutils \
  git

WORKDIR /build

ENV HOME=/root

# Klone und installiere vimrc.
RUN git clone --depth=1 https://github.com/amix/vimrc.git ${HOME}/.vim_runtime \
  && sh ${HOME}/.vim_runtime/install_awesome_vimrc.sh \
  || echo "Vimrc setup partially completed or had non-critical errors, continuing build."

# Lade verschiedene CLI-Tools herunter und installiere sie.
# Verwende TARGETOS und TARGETARCH für plattformspezifische Downloads.
RUN \
  # Download Cilium CLI
  CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt) && \
  echo "Fetching Cilium CLI v${CILIUM_CLI_VERSION} for ${TARGETOS}-${TARGETARCH}" && \
  curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-${TARGETOS}-${TARGETARCH}.tar.gz{,.sha256sum} && \
  sha256sum -c cilium-${TARGETOS}-${TARGETARCH}.tar.gz.sha256sum && \
  tar -xzvf cilium-${TARGETOS}-${TARGETARCH}.tar.gz cilium && \
  mv cilium /usr/local/bin/cilium && \
  chmod +x /usr/local/bin/cilium && \
  rm cilium-${TARGETOS}-${TARGETARCH}.tar.gz cilium-${TARGETOS}-${TARGETARCH}.tar.gz.sha256sum && \
  \
  # Download Kubeseal CLI
  KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | jq -r '.tag_name' | sed 's/^v//') && \
  echo "Fetching Kubeseal v${KUBESEAL_VERSION} for ${TARGETOS}-${TARGETARCH}" && \
  curl -OL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz" && \
  tar -xzvf kubeseal-${KUBESEAL_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz kubeseal && \
  mv kubeseal /usr/local/bin/kubeseal && \
  chmod +x /usr/local/bin/kubeseal && \
  rm kubeseal-${KUBESEAL_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz && \
  \
  # Download ArgoCD CLI
  ARGOCD_VERSION=$(curl -L -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION) && \
  echo "Fetching ArgoCD CLI v${ARGOCD_VERSION} for ${TARGETOS}-${TARGETARCH}" && \
  curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-${TARGETOS}-${TARGETARCH} && \
  chmod +x /usr/local/bin/argocd && \
  \
  # Download Velero CLI
  VELERO_VERSION=$(curl -s https://api.github.com/repos/vmware-tanzu/velero/releases/latest | jq -r '.tag_name' | sed 's/^v//') && \
  VELERO_ARCHIVE="velero-v${VELERO_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz" && \
  VELERO_BINARY_PATH_IN_ARCHIVE="velero-v${VELERO_VERSION}-${TARGETOS}-${TARGETARCH}/velero" && \
  echo "Fetching Velero CLI v${VELERO_VERSION} for ${TARGETOS}-${TARGETARCH}" && \
  curl -OL "https://github.com/vmware-tanzu/velero/releases/download/v${VELERO_VERSION}/${VELERO_ARCHIVE}" && \
  tar -xzvf "${VELERO_ARCHIVE}" -C /usr/local/bin/ "${VELERO_BINARY_PATH_IN_ARCHIVE}" --strip-components=1 && \
  chmod +x /usr/local/bin/velero && \
  rm "${VELERO_ARCHIVE}"


# ---- Final Stage ----
# This is the actual image that will be created.
FROM alpine:latest

ENV HOME=/root \
  KREW_ROOT=${HOME}/.krew

ENV PATH="${KREW_ROOT}/bin:${PATH}"

RUN apk add --update --no-cache \
  zsh \
  rsync \
  vim \
  git \
  curl \
  tar \
  kubectl \
  helm \
  kubectx \
  k9s \
  openssh-client \
  jq \
  yq \
  byobu \
  ansible-core \
  ansible-lint \
  flux \
  oh-my-zsh \
  zsh-theme-powerlevel10k \
  coreutils \
  && rm -rf /var/cache/apk/*

# Copy pre-downloaded/built binaries from the builder stage.
COPY --from=builder /usr/local/bin/cilium /usr/local/bin/cilium
COPY --from=builder /usr/local/bin/kubeseal /usr/local/bin/kubeseal
COPY --from=builder /usr/local/bin/argocd /usr/local/bin/argocd
COPY --from=builder /usr/local/bin/velero /usr/local/bin/velero

# Copy user-provided configuration files.
COPY zshenv /etc/zsh/zshenv
COPY ssh.conf /etc/ssh/ssh_config.d/ssh.conf
COPY zshrc-default.zsh /etc/zsh/zshrc.d/zhsrc-default.zsh

# Copy configured vim setup from the builder stage.
COPY --from=builder ${HOME}/.vim_runtime ${HOME}/.vim_runtime
COPY --from=builder ${HOME}/.vimrc ${HOME}/.vimrc

# Configure Zsh, Oh My Zsh, Powerlevel10k, and Byobu.
RUN \
  mkdir -p ${HOME}/.local/share/zsh/plugins && \
  if [ -d /usr/share/zsh/plugins/powerlevel10k ]; then \
      ln -s /usr/share/zsh/plugins/powerlevel10k ${HOME}/.local/share/zsh/plugins/powerlevel10k; \
    elif [ -d /usr/share/oh-my-zsh/custom/themes/powerlevel10k ]; then \
      ln -s /usr/share/oh-my-zsh/custom/themes/powerlevel10k ${HOME}/.local/share/zsh/plugins/powerlevel10k; \
    else \
      echo "Warning: Powerlevel10k directory not found at expected locations for symlinking."; \
    fi && \
  mkdir -p ${HOME}/.config/byobu && \
  echo 'set-option -g default-shell /bin/zsh' > ${HOME}/.config/byobu/.tmux.conf

# Install Ansible collections.
# community.general is large; consider specific sub-collections if possible.
RUN rm -rf ${HOME}/.ansible/tmp/* ${HOME}/.ansible/cp/*

# Install Krew (Kubectl plugin manager) and specified plugins.
RUN set -x; \
  KREW_TEMP_DIR=$(mktemp -d); \
  cd "${KREW_TEMP_DIR}" && \
  OS_ENV="$(uname -s | tr '[:upper:]' '[:lower:]')" && \
  ARCH_ENV="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
  KREW_BINARY="krew-${OS_ENV}_${ARCH_ENV}" && \
  echo "Fetching Krew for ${OS_ENV}-${ARCH_ENV}" && \
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW_BINARY}.tar.gz" && \
  tar zxvf "${KREW_BINARY}.tar.gz" && \
  ./"${KREW_BINARY}" install krew && \
  kubectl krew version && \
  kubectl krew install \
    images \
    ktop \
    np-viewer \
    outdated \
    plogs \
    rbac-tool \
    sick-pods \
    status \
    stern \
    view-allocations \
    view-cert \
    view-quotas \
    view-secret \
    view-utilization \
    virt && \
  cd / && \
  rm -rf "${KREW_TEMP_DIR}" && \
  rm -rf /tmp/*

# Set the default working directory for the container.
WORKDIR ${HOME}/data

# Optional: Set a default command (e.g., start Zsh).
CMD ["/bin/zsh"]

# To build this Dockerfile:
# podman build --platform linux/amd64,linux/arm64 --manifest kubetool .
#
# To run:
# podman run -it -v $HOME/.kube:$HOME/.kube:z --rm kubetools
