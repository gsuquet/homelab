.PHONY: help install install-python install-ansible uninstall

# Default target
.DEFAULT_GOAL := help

# Variables
PYTHON_VERSION=3.12
ANSIBLE_VERSION=10.2.0 # renovate: datasource=pypi depName=ansible
ANSIBLE_CREATOR_VERSION=24.7.1 # renovate: datasource=pypi depName=ansible-creator

PACKAGE_MANAGER=$(shell if command -v brew >/dev/null 2>&1; then echo "brew"; elif command -v apt-get >/dev/null 2>&1; then echo "apt-get"; elif command -v apk >/dev/null 2>&1; then echo "apk"; else echo "unsupported"; fi)

help:
	@echo "Available commands:"
	@echo "  install          - Install all required tools and dependencies"
	@echo "  install-python   - Install Python $(PYTHON_VERSION)"
	@echo "  install-ansible  - Install Ansible $(ANSIBLE_VERSION) and Ansible Creator $(ANSIBLE_CREATOR_VERSION)"
	@echo "  uninstall        - Clean up installed tools and dependencies"

install: install-python install-ansible

install-python:
	@echo "Installing Python $(PYTHON_VERSION)..."
ifeq ($(PACKAGE_MANAGER),brew)
	brew update
	brew install python@$(PYTHON_VERSION)
	brew link --force --overwrite python@$(PYTHON_VERSION)
else ifeq ($(PACKAGE_MANAGER),apt-get)
	sudo apt-get update
	sudo apt-get install -y python$(PYTHON_VERSION) python3-pip
else ifeq ($(PACKAGE_MANAGER),apk)
	sudo apk update
	sudo apk add python3 py3-pip
else
	@echo "Unsupported package manager. Please install Python manually."
	exit 1
endif

install-ansible:
	@echo "Installing Ansible $(ANSIBLE_VERSION) and Ansible Creator $(ANSIBLE_CREATOR_VERSION)..."
	pip3 install ansible==$(ANSIBLE_VERSION) ansible-creator==$(ANSIBLE_CREATOR_VERSION)

uninstall:
	@echo "Cleaning up..."
	pip3 uninstall -y ansible ansible-creator
ifeq ($(PACKAGE_MANAGER),brew)
	brew uninstall python@$(PYTHON_VERSION)
else ifeq ($(PACKAGE_MANAGER),apt-get)
	sudo apt-get remove -y python$(PYTHON_VERSION)
else ifeq ($(PACKAGE_MANAGER),apk)
	sudo apk del python3 py3-pip
endif
