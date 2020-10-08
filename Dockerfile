# extend the official jenkins slave base image
FROM openshift/jenkins-slave-base-centos7:v3.11

# specify wanted version of python
ENV PYTHON_VERSION=3.6.1 \
    LANG=de_CH.UTF-8

# install python
RUN set -x \
    && sed -i 's/override_install_langs=en_US.utf8/#override_install_langs=en_US.utf8/g' /etc/yum.conf \
    && yum update -y glibc-common \
    && localedef -c -i de_CH -f UTF-8 de_CH.UTF-8 \
    && echo "LANG=de_CH.UTF-8" > /etc/locale.conf \
    && chown -R root:root /home/jenkins \
    && INSTALL_PKGS="gcc make openssl-devel wget zlib-devel epel-release" \
    && yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS \
    && cd /tmp \
    && wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz \
    && tar xf Python-${PYTHON_VERSION}.tgz \
    && cd Python-${PYTHON_VERSION} \
    && ./configure \
    && make altinstall \
    && cd .. \
    && rm -rf Python-${Python_VERSION} \
    && yum install -y --setopt=tsflags=nodocs python3-pip uwsgi uwsgi-python3 postgresql-dev python3-dev musl-dev \
    && yum remove -y $INSTALL_PKGS \
    && yum clean all \
    && rm -rf /var/cache/yum \
    && chown 1001:0 /home/jenkins

RUN groupadd -r www-data \
	&& useradd -r -d /var/www/ -s /sbin/nologin -g www-data www-data

ADD . /srv/qwc_service
RUN grep -lr "app.run(host='localhost'," /srv/qwc_service | grep -v .svn | xargs sed -i -e "s/app.run(host='localhost',/app.run(host='0.0.0.0',/g" \
    && pip3 install --no-cache-dir -r /srv/qwc_service/requirements.txt \
    && chmod u+x /srv/qwc_service/* \
    && chown 1001:0 /srv/qwc_service

ENV SERVICE_MOUNTPOINT='/'
# http://uwsgi-docs.readthedocs.io/en/latest/Options.html#buffer-size
ENV REQ_HEADER_BUFFER_SIZE=12288
ENV UWSGI_PROCESSES=1
ENV UWSGI_THREADS=4

RUN echo uwsgi uwsgi --http-socket :9090 --buffer-size $REQ_HEADER_BUFFER_SIZE --processes $UWSGI_PROCESSES \
    --threads $UWSGI_THREADS --plugins python3 --protocol uwsgi --wsgi-disable-file-wrapper --uid www-data \
    --gid www-data --master --chdir /srv/qwc_service --mount $SERVICE_MOUNTPOINT=server:app \
    --manage-script-name >/docker-entrypoint.sh

# switch to non-root for openshift usage
USER 1001
