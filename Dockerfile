FROM npohosting/base:3.7

LABEL maintainer="NPO Hosting <hosting@npo.nl>"

ENV OC_VERSION=v3.10.0
ENV OC_HASH=dd10d17
ENV GLIBC_VERSION=2.27-r0
ENV GLIBC_URL=https://github.com/sgerrand/alpine-pkg-glibc/releases/download
ENV GLIBC_PUB=https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub

RUN echo "## Install Basic Tools" \
    && apk add --no-cache \
            bash \
            curl \
            vim \
            openssl \
            ca-certificates \
            jq \
            nginx \
    && echo "## Install glibc" \
    && curl -s -L -o /tmp/glibc-${GLIBC_VERSION}.apk ${GLIBC_URL}/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk \
    && curl -s -L -o /tmp/glibc-bin-${GLIBC_VERSION}.apk ${GLIBC_URL}/${GLIBC_VERSION}/glibc-bin-${GLIBC_VERSION}.apk \
    && curl -s -L -o /tmp/glibc-i18n-${GLIBC_VERSION}.apk ${GLIBC_URL}/${GLIBC_VERSION}/glibc-i18n-${GLIBC_VERSION}.apk \
    && curl -s -L -o /etc/apk/keys/sgerrand.rsa.pub ${GLIBC_PUB} \
    && apk add --no-cache \
            /tmp/glibc-${GLIBC_VERSION}.apk \
            /tmp/glibc-bin-${GLIBC_VERSION}.apk \
            /tmp/glibc-i18n-${GLIBC_VERSION}.apk \
    && rm /etc/apk/keys/sgerrand.rsa.pub \
    && /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 "$LANG" || true \
    && echo "export LANG=$LANG" > /etc/profile.d/locale.sh \
    && apk del glibc-i18n \
    && echo "### Install Tool : OpenShift Client" \
    && curl -s -L -o /tmp/oc.tgz \
          https://github.com/openshift/origin/releases/download/${OC_VERSION}/openshift-origin-client-tools-${OC_VERSION}-${OC_HASH}-linux-64bit.tar.gz \
    && tar -zx -C /tmp -f /tmp/oc.tgz \
    && cp /tmp/openshift-origin-client-tools-${OC_VERSION}-${OC_HASH}-linux-64bit/oc /usr/local/bin/ \
    && echo "## Clean-up" \
    && rm -rf /tmp/*

COPY root/ /
ADD https://raw.githubusercontent.com/lukas2511/dehydrated/master/dehydrated /usr/bin/dehydrated

RUN chmod +x /run.sh \
    && chown -R 1001:1001 /var/*/nginx \
    && chmod -R a+rw /var/*/nginx \
    && chmod a+rwx /var/*/nginx \
    && chmod a+rx /usr/bin/dehydrated \
    && chmod a+rw /usr/local/etc/dehydrated \
    && chmod a+rw /usr/share/nginx/html/.well-known/acme-challenge

USER 1001

CMD ["/run.sh"]
