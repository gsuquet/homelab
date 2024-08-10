FROM mcr.microsoft.com/devcontainers/python:1.1.12-3.12-bookworm@sha256:af9cee7bc6292c7414966238cbb651bb06d2d7136aed9989e29ef45038f90503

# renovate: datasource=pypi depName=ansible
ARG ANSIBLE_VERSION=10.2.0
# renovate: datasource=pypi depName=ansible-creator
ARG ANSIBLE_CREATOR_VERSION=24.7.1

RUN pip install ansible==${ANSIBLE_VERSION} ansible-creator==${ANSIBLE_CREATOR_VERSION}
