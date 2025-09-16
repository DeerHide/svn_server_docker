FROM ubuntu:24.04

ARG HOME_DIR=/home/svn

RUN apt-get update && \
    apt-get install -y --no-install-recommends subversion=1.14.3-1build4 adduser=3.137ubuntu1 perl=5.38.2-3.2ubuntu0.2 && \
    addgroup svn --system && \
    adduser svn --system --home /home/svn --no-create-home --ingroup svn && \
    deluser --remove-home ubuntu && \
    mkdir -p ${HOME_DIR} && \
    mkdir -p /etc/subversion && \
    mkdir -p /var/log/svn && \
    chown -R svn:svn ${HOME_DIR} && \
    chown -R svn:svn /var/log/svn && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY subversion/svnserve.conf /etc/subversion/svnserve.conf
COPY subversion/passwd /etc/subversion/passwd

RUN chmod o-r /etc/subversion/svnserve.conf && \
    chmod o-r /etc/subversion/passwd && \
    chown -R svn:svn /etc/subversion

USER svn

EXPOSE 3690

CMD ["/usr/bin/svnserve", "-d", "--foreground", "-r", "/home/svn", "--listen-port", "3690", "--log-file=/var/log/svn/svnserve.log"]