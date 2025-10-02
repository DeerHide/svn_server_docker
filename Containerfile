FROM ubuntu:24.04

ARG APP_UID=1000
ARG APP_GID=1000
ARG HOME_DIR=/home/svn

LABEL org.opencontainers.image.description="Secure Subversion server on Ubuntu 24.04 with multi-user support."

RUN apt-get update && \
    apt-get install -y --no-install-recommends subversion adduser perl tini iproute2 && \
    deluser --remove-home ubuntu || true && \
    addgroup --system --gid ${APP_GID} svn && \
    adduser --system --uid ${APP_UID} --home ${HOME_DIR} --no-create-home --ingroup svn svn && \
    mkdir -p ${HOME_DIR} && \
    mkdir -p /etc/subversion && \
    mkdir -p /var/log/svn && \
    chown -R svn:svn ${HOME_DIR} && \
    chown -R svn:svn /var/log/svn && \
    chmod 755 ${HOME_DIR} && \
    chmod 755 /var/log/svn && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Stash default Subversion configs for first-run seeding and also place them in /etc/subversion
RUN mkdir -p /usr/local/share/subversion-defaults
COPY src/subversion/ /usr/local/share/subversion-defaults/
COPY src/subversion/ /etc/subversion/

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

RUN chmod o-r /etc/subversion/* && \
    chown -R svn:svn /etc/subversion && \
    usermod -s /bin/bash svn && \
    echo 'export PS1="svn@svn-server:\\w$ "' >> ${HOME_DIR}/.bashrc && \
    chmod 644 ${HOME_DIR}/.bashrc

USER svn

EXPOSE 3690

HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD /usr/local/bin/healthcheck.sh || exit 1
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
