## Build Arguments ##
#####################
## Set the python image tag to use as the base image. 
# Set default below to desired Python version.
ARG PYTHON_TAG=3.11
##

## Set the UID/GID that sopel will run and make files/folders as.
# For security, these values are set past the upper limit of named users in most
# linux environments. `chown` any volume mounts to the IDs specified here, or 
# change to match your GID (and UID if desired) if you think its okay ¯\_(ツ)_/¯
ARG SOPEL_GID=1000
ARG SOPEL_UID=1000
##

## Set the repository used to pull the sopel source
# Set Docker build-arg SOPEL_REPO with private fork, or change default below 
# as desired. Any valid Git URL is acceptable.
ARG SOPEL_REPO=https://github.com/sopel-irc/sopel.git
##

## Set the specific branch/commit for the source
# This can be a branch name, release/tag, or even specific commit hash.
# Set Docker build-arg SOPEL_BRANCH, or replace the default value below.
ARG SOPEL_BRANCH=v8.0.1
##

#####
### STAGE 1: Pull latest source
#####
FROM debian:latest AS git-fetch-stage

ARG SOPEL_REPO
ARG SOPEL_BRANCH

RUN set -ex \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
  && git clone \
    --depth 1 --branch ${SOPEL_BRANCH} \
    ${SOPEL_REPO} /sopel-src \
  && apt-get remove --purge -y git \
  && apt-get autoremove -y \
  && apt-get clean

#####
### STAGE 2: Install Sopel
#####
FROM python:${PYTHON_TAG} AS build-stage

# Pre-set ARGs
ARG SOPEL_BRANCH
# Injected ARGs
ARG BUILD_DATE
ARG VCS_REF
ARG DOCKERFILE_VCS_REF
LABEL maintainer="Humorous Baby <humorbaby@humorbaby.net>" \
      org.label-schema.build-date="${BUILD_DATE}" \
      org.label-schema.name="sopel" \
      org.label-schema.description=" \
        Sopel, the Python IRC bot. \
        For stand-alone or compose/stack service use." \
      org.label-schema.url="https://sopel.chat" \
      org.label-schema.vcs-url="https://github.com/sopel-irc/sopel" \
      org.label-schema.vcs-ref="${VCS_REF}" \
      org.label-schema.version="Python ${PYTHON_VERSION}/Sopel ${SOPEL_BRANCH}" \
      org.label-schema.schema-version="1.0" \
      dockerfile.vcs-url="https://github.com/sopel-irc/docker-sopel" \
      dockerfile.vcf-ref="${DOCKERFILE_VCS_REF}"

ARG SOPEL_GID
ARG SOPEL_UID

RUN set -ex \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    gcc \
    build-essential \
    sudo \
    gosu \
  && groupadd -g ${SOPEL_GID} sopel \
  && useradd -u ${SOPEL_UID} -g sopel -m -s /bin/bash sopel \
  && mkdir /home/sopel/.sopel \
  && chown sopel:sopel /home/sopel/.sopel

WORKDIR /home/sopel

COPY --from=git-fetch-stage --chown=sopel:sopel /sopel-src /home/sopel/sopel-src
RUN set -ex \
  && cd ./sopel-src \
  && gosu sopel python -m pip install . \
  && cd .. \
  && rm -rf ./sopel-src \
  && apt-get purge -y --auto-remove \
    gcc \
    build-essential \
  && apt-get clean

VOLUME [ "/home/sopel/.sopel" ]

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "sopel" ]
