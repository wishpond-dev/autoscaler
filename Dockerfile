FROM ruby:2.7-slim

# Install required system packages and dependencies
RUN apt-get update && apt-get install -y ca-certificates curl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.18.0/bin/linux/amd64/kubectl && \
  chmod +x kubectl && \
  mv kubectl /usr/local/bin/kubectl

COPY autoscaler.rb /

USER 1001
ENTRYPOINT [ "ruby" ]
CMD [ "autoscaler.rb" ]
