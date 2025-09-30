FROM ubuntu:24.04

ARG APP_UID=1000
ARG APP_GID=1000
ARG HOME_DIR=/home/svn

LABEL org.opencontainers.image.description="Secure Subversion server on Ubuntu 24.04 with multi-user support."

RUN apt-get update && \
    apt-get install -y --no-install-recommends subversion adduser perl openssh-server iproute2 tini && \
    deluser --remove-home ubuntu || true && \
    addgroup --system --gid ${APP_GID} svn && \
    adduser --system --uid ${APP_UID} --home ${HOME_DIR} --no-create-home --ingroup svn svn && \
    mkdir -p ${HOME_DIR} && \
    mkdir -p /etc/subversion && \
    mkdir -p /run/sshd && \
    mkdir -p /var/log/svn && \
    chown -R svn:svn ${HOME_DIR} && \
    chown -R svn:svn /var/log/svn && \
    chmod 755 ${HOME_DIR} && \
    chmod 755 /var/log/svn && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Stash default Subversion configs for first-run seeding and also place them in /etc/subversion
RUN mkdir -p /usr/local/share/subversion-defaults
COPY src/subversion/svnserve.conf /usr/local/share/subversion-defaults/svnserve.conf
COPY src/subversion/passwd /usr/local/share/subversion-defaults/passwd
COPY src/subversion/svnserve.conf /etc/subversion/svnserve.conf
COPY src/subversion/passwd /etc/subversion/passwd
COPY src/ssh/sshd_config /etc/ssh/sshd_config


RUN chmod o-r /etc/subversion/svnserve.conf && \
    chmod o-r /etc/subversion/passwd && \
    chown -R svn:svn /etc/subversion && \
    usermod -s /bin/bash svn && \
    echo 'export PS1="svn@svn-server:\\w$ "' >> ${HOME_DIR}/.bashrc && \
    chmod 644 ${HOME_DIR}/.bashrc && \
    mkdir -p ${HOME_DIR}/.ssh && \
    chown -R svn:svn ${HOME_DIR}/.ssh && \
    chmod 700 ${HOME_DIR}/.ssh && \
    touch ${HOME_DIR}/.ssh/authorized_keys && \
    chmod 600 ${HOME_DIR}/.ssh/authorized_keys

EXPOSE 3690
EXPOSE 22


HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD /usr/local/bin/healthcheck.sh || exit 1
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh

RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh && \
    chmod 755 /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh
