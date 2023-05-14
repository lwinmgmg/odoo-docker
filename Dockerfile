FROM alpine:latest AS gitcloner
ENV ODOO_VERSION=16.0
ENV ODOO_REPO=https://github.com/lwinmgmg/odoo

WORKDIR /build

RUN wget ${ODOO_REPO}/archive/refs/heads/${ODOO_VERSION}.zip

RUN unzip 16.0.zip

RUN ls -ahl

FROM python:3.10-slim-bullseye

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

RUN echo "deb http://ftp.de.debian.org/debian bullseye main" | tee -a  /etc/apt/sources.list

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y ca-certificates \
                build-essential \
                curl \
                dirmngr \
                fonts-noto-cjk \
                gnupg \
                libssl-dev \
                node-less \
                npm \
                python3-num2words \
                python3-pdfminer \
                python3-pip \
                python3-phonenumbers \
                python3-pyldap \
                python3-qrcode \
                python3-renderpm \
                python3-setuptools \
                python3-slugify \
                python3-vobject \
                python3-watchdog \
                python3-xlrd \
                python3-xlwt \
                xz-utils \
                wkhtmltopdf

RUN apt-get -y install libpq5 && \
    apt-get install -y libsasl2-dev \
                        libldap2-dev \
                        libssl-dev \
                        libpq-dev

RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ bullseye-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update  \
    && apt-get install --no-install-recommends -y postgresql-client \
    && rm -f /etc/apt/sources.list.d/pgdg.list \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g rtlcss

RUN apt-get clean && \
    apt-get autoclean && \
    apt-get autoremove

RUN python -m pip install setuptools==66.1.1 && \
    python -m pip install pip==22.3.1

ARG ODOO_RELEASE=20230128

ENV PATH=${PATH}:/usr/lib/postgresql/14/bin
ENV ODOO_USER=odoo
ENV ODOO_VERSION=16.0
ENV ODOO_USER_HOME_DIR="/home/${ODOO_USER}"
ENV ODOO_USER_UID=999
ENV ODOO_INSTALL_DIR="${ODOO_USER_HOME_DIR}/${ODOO_VERSION}"
ENV ODOO_REPO=https://github.com/lwinmgmg/odoo.git
# Create odoo user
RUN groupadd --gid ${ODOO_USER_UID} ${ODOO_USER} \
    && useradd -m --uid ${ODOO_USER_UID} --gid ${ODOO_USER_UID} \
    --shell /bin/bash ${ODOO_USER}

RUN chown odoo:odoo -R ${ODOO_USER_HOME_DIR}

COPY --from=gitCloner --chown=${ODOO_USER}:${ODOO_USER} /build/odoo-16.0 ${ODOO_INSTALL_DIR}/

COPY dev-requirements.txt ${ODOO_INSTALL_DIR}/.

RUN mkdir /etc/odoo && chown odoo:odoo -R /etc/odoo
RUN mkdir /var/lib/odoo && chown odoo:odoo -R /var/lib/odoo
ENV DATA_DIR=${ODOO_USER_HOME_DIR}/.local/share/Odoo
RUN mkdir -p ${DATA_DIR} && chown odoo:odoo ${DATA_DIR}

USER odoo

WORKDIR ${ODOO_USER_HOME_DIR}

RUN python -m venv .venv

ENV PATH=${ODOO_USER_HOME_DIR}/.venv/bin:${PATH}

WORKDIR ${ODOO_INSTALL_DIR}

RUN pip install -r requirements.txt
RUN pip install -r dev-requirements.txt

COPY ./entrypoint.sh /
COPY ./odoo.conf /etc/odoo/

VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]
EXPOSE 8069 8071 8072
ENV ODOO_RC /etc/odoo/odoo.conf
COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py
ENTRYPOINT ["/entrypoint.sh"]

CMD [ "odoo" ]
