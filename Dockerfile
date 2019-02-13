FROM alpine:3.8

LABEL maintainer devops@travelaudience.com

# Example environment variable - please add the real values in your kubernetes manifest or 'docker run' command.
ENV NEXUS_AUTH="abcd:1234"
ENV NEXUS_URL="https://nexus.example.com"

# You can overwrite this env var if your docker repo is named differently 
ENV NEXUS_REPO='docker-hosted'

ADD cleanup-job.sh /cleanup-job.sh
ADD scripts/dockerCleanup.groovy /scripts/dockerCleanup.groovy

RUN apk add --no-cache --update bash curl coreutils

ENTRYPOINT ["/cleanup-job.sh"]
