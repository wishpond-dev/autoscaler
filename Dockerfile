FROM ruby:2.7-slim

# Install required system packages and dependencies
RUN apt-get update && apt-get install -y ca-certificates wget
RUN wget -nc -P /tmp/bitnami/pkg/cache/ https://downloads.bitnami.com/files/stacksmith/kubectl-1.12.10-1-linux-amd64-debian-9.tar.gz && \
    echo "57612b8cc7b8c93a708cd5f5314d824a153db26764aa7cbe80230ed6b32e7db0  /tmp/bitnami/pkg/cache/kubectl-1.12.10-1-linux-amd64-debian-9.tar.gz" | sha256sum -c - && \
    tar -zxf /tmp/bitnami/pkg/cache/kubectl-1.12.10-1-linux-amd64-debian-9.tar.gz -P --transform 's|^[^/]*/files|/opt/bitnami|' --wildcards '*/files' && \
    rm -rf /tmp/bitnami/pkg/cache/kubectl-1.12.10-1-linux-amd64-debian-9.tar.gz

RUN chmod +x /opt/bitnami/kubectl/bin/kubectl
ENV BITNAMI_APP_NAME="kubectl" \
    BITNAMI_IMAGE_VERSION="1.12.10-debian-9-r77" \
    PATH="/opt/bitnami/kubectl/bin:$PATH"

COPY autoscaler.rb /

USER 1001
ENTRYPOINT [ "ruby" ]
CMD [ "autoscaler.rb" ]
