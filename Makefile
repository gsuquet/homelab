.PHONY: help

# Default target
.DEFAULT_GOAL := help

PACKAGE_MANAGER=$(shell if command -v brew >/dev/null 2>&1; then echo "brew"; elif command -v apt-get >/dev/null 2>&1; then echo "apt-get"; elif command -v apk >/dev/null 2>&1; then echo "apk"; elif command -v choco >/dev/null 2>&1; then echo "choco"; else echo "unsupported"; fi)

help:
	@echo "Available commands:"
	@echo "  install            - Install all required tools and dependencies"
	@echo "  install-rpi-imager - Install Raspberry Pi Imager"
	@echo "  uninstall          - Clean up installed tools and dependencies"

install: install-rpi-imager

install-rpi-imager:
	@echo "Installing Raspberry Pi Imager..."
ifeq ($(PACKAGE_MANAGER),brew)
	brew update
	brew install --cask raspberry-pi-imager
else ifeq ($(PACKAGE_MANAGER),apt-get)
	sudo apt-get update
	sudo apt-get install -y rpi-imager
else ifeq ($(PACKAGE_MANAGER),apk)
	sudo apk update
	sudo apk add rpi-imager
else ifeq ($(PACKAGE_MANAGER),choco)
	choco install -y rpi-imager
else
	@echo "Unsupported package manager. Please download and install Raspberry Pi Imager manually."
	exit 1
endif

uninstall:
	@echo "Uninstalling Raspberry Pi Imager..."
ifeq ($(PACKAGE_MANAGER),brew)
	brew uninstall --cask raspberry-pi-imager
else ifeq ($(PACKAGE_MANAGER),apt-get)
	sudo apt-get remove -y rpi-imager
else ifeq ($(PACKAGE_MANAGER),apk)
	sudo apk del rpi-imager
else ifeq ($(PACKAGE_MANAGER),choco)
	choco uninstall -y rpi-imager
else
	@echo "Unsupported package manager. Please uninstall Raspberry Pi Imager manually."
	exit 1
endif
