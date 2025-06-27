DISTRO    := $(shell dpkg --status tzdata|grep Provides|cut -f2 -d'-')
ARCH      := $(shell dpkg --print-architecture)

ITGMANIA_BASE_DIR := /usr/local/itgmania

.EXPORT_ALL_VARIABLES:

ifeq ($(wildcard ./venv/bin/rpi-hw-info),)
#####
# rpi-hw-info not installed; install it so we can detect the rpi model
#####
all: rpi-hw-info-setup
	$(MAKE) all

rpi-hw-info-setup:
	python3 -m venv venv
	./venv/bin/pip install --upgrade pip
	./venv/bin/pip install rpi-hw-info~=2.0
	@ if ! [ -e ./venv/bin/rpi-hw-info ]; then echo "Failed to install rpi-hw-info. Check Python and pip setup."; exit 1; fi

%: rpi-hw-info-setup
	$(MAKE) $@

else
#####
# able to detect rpi model; can actually build the package
#####

RPI_MODEL := $(shell ./venv/bin/rpi-hw-info 2>/dev/null | awk -F ':' '{print $$1}' | tr '[:upper:]' '[:lower:]' )

ifeq ($(RPI_MODEL),3b+)
# RPI 3B and 3B+ are the same hardware architecture and targets
# So we don't need to generate separate packages for them.
# Prefer the base model "3B" for labelling when we're on a 3B+
RPI_MODEL=3b
endif

# Read the one itgmania binary and get version, hash, and date
ITGMANIA_VERSION_HASH_DATE   :=$(shell ./extract-version-from-binary.sh $(ITGMANIA_BASE_DIR)/itgmania --version-hash-date)
ITGMANIA_VERSION_NUM         :=$(shell echo "$(ITGMANIA_VERSION_HASH_DATE)" | cut -d' ' -f1)
ITGMANIA_HASH                :=$(shell echo "$(ITGMANIA_VERSION_HASH_DATE)" | cut -d' ' -f2)
ITGMANIA_DATE                :=$(shell echo "$(ITGMANIA_VERSION_HASH_DATE)" | cut -d' ' -f3)
ITGMANIA_VERSION_MAJOR_MINOR :=$(shell echo "$(ITGMANIA_VERSION_NUM)" | sed 's/\.[^.]*$$//')

PACKAGE_NAME                 = itgmania-$(RPI_MODEL)
PACKAGE_SPEC_NAME            = itgmania-$(ITGMANIA_VERSION_MAJOR_MINOR)
PACKAGE_SPEC_DIR             := $(ARCH)/$(PACKAGE_SPEC_NAME)

PACKAGER_NAME:=$(shell id -nu)
PACKAGER_EMAIL:=$(shell git config --global user.email)
PACKAGER_EMAIL ?= nobody@example.com
PACKAGE_DATE:=$(shell date +"%a, %d %b %Y %H:%M:%S %z")

ifeq ($(RELEASE),true)
ITGMANIA_VERSION=$(ITGMANIA_VERSION_NUM)
ITGMANIA_DISTRIBUTION=stable
else
ITGMANIA_VERSION=$(ITGMANIA_VERSION_NUM)-$(ITGMANIA_DATE)
ITGMANIA_DISTRIBUTION=UNRELEASED
endif


.PHONY: all
all: execute-bit packages validate
	# Prep staging dir
	rm -rf target/$(PACKAGE_SPEC_DIR)
	mkdir -p target/$(PACKAGE_SPEC_DIR)
	# copy packaging metadata for this version into staging dir
	rsync -v --update --recursive $(PACKAGE_SPEC_DIR)/* target/$(PACKAGE_SPEC_DIR)
	# copy built itgmania into staging dir
	mkdir -p target/$(PACKAGE_SPEC_DIR)/usr/games/$(PACKAGE_SPEC_NAME)
	rsync --update --recursive $(ITGMANIA_BASE_DIR)/* target/$(PACKAGE_SPEC_DIR)/usr/games/$(PACKAGE_SPEC_NAME)/.
	$(MAKE) $(PACKAGE_SPEC_NAME)
.PHONY: all

itgmania-%: \
	target/$(PACKAGE_SPEC_DIR)/DEBIAN/control \
	target/$(PACKAGE_SPEC_DIR)/usr/share/doc/$(PACKAGE_NAME)/changelog.Debian.gz \
	target/$(PACKAGE_SPEC_DIR)/usr/share/doc/$(PACKAGE_NAME)/copyright \
	target/$(PACKAGE_SPEC_DIR)/usr/share/lintian/overrides/$(PACKAGE_NAME) \
	target/$(PACKAGE_SPEC_DIR)/usr/games/$(PACKAGE_SPEC_NAME)/itgmania \
	target/$(PACKAGE_SPEC_DIR)/usr/share/man/man6/itgmania.6.gz \
	target/$(PACKAGE_SPEC_DIR)/usr/bin/itgmania
	cd target && fakeroot dpkg-deb --build $(PACKAGE_SPEC_DIR)
	mv target/$(PACKAGE_SPEC_DIR).deb target/itgmania-$(RPI_MODEL)_$(ITGMANIA_VERSION)_$(DISTRO).deb
	lintian target/itgmania-$(RPI_MODEL)_$(ITGMANIA_VERSION)_$(DISTRO).deb

# itgmania symlink on the PATH
target/$(PACKAGE_SPEC_DIR)/usr/bin/itgmania:
	mkdir -p $(@D)
	ln -s ../games/$(PACKAGE_SPEC_NAME)/itgmania $@

# debian control files get envvars substituted FRESH EVERY TIME
.PHONY: target/$(PACKAGE_SPEC_DIR)/DEBIAN/*
target/$(PACKAGE_SPEC_DIR)/DEBIAN/*: ITGMANIA_DEPS=$(shell ./find-bin-dep-pkg.py --display debian-control $(ITGMANIA_BASE_DIR)/itgmania)
target/$(PACKAGE_SPEC_DIR)/DEBIAN/*:
	cat $(PACKAGE_SPEC_DIR)/DEBIAN/$(@F) | envsubst > $@

# lintian overrides file must be substituted and renamed
target/$(PACKAGE_SPEC_DIR)/usr/share/lintian/overrides/$(PACKAGE_NAME): $(PACKAGE_SPEC_DIR)/usr/share/lintian/overrides/itgmania
	cat $(<) | envsubst > $(basename $@)

# changelog must be substituted and compressed
target/$(PACKAGE_SPEC_DIR)/usr/share/doc/$(PACKAGE_NAME)/changelog.Debian.gz: $(PACKAGE_SPEC_DIR)/usr/share/doc/itgmania/changelog.Debian
	mkdir -p $(shell dirname $@)
	cat $(<) | envsubst > $(basename $@)
	gzip --no-name $(basename $@)

# copyright gets renamed
target/$(PACKAGE_SPEC_DIR)/usr/share/doc/$(PACKAGE_NAME)/copyright: $(PACKAGE_SPEC_DIR)/usr/share/doc/itgmania/copyright
	cp $(<) $@

# manpages must be compressed
target/$(PACKAGE_SPEC_DIR)/usr/share/man/man6/itgmania.6.gz: $(PACKAGE_SPEC_DIR)/usr/share/man/man6/itgmania.6
	gzip --no-name -9 $(basename $@)

# itgmania needs stripping
.PHONY: target/$(PACKAGE_SPEC_DIR)/usr/games/$(PACKAGE_SPEC_NAME)/itgmania
target/$(PACKAGE_SPEC_DIR)/usr/games/$(PACKAGE_SPEC_NAME)/itgmania:
	strip --strip-unneeded $@

# Install deb package linter
.PHONY: packages
packages:
	sudo apt-get install -y \
		binutils \
		lintian

.PHONY: execute-bit
execute-bit:
	chmod a+x find-bin-dep-pkg.py
	chmod a+x extract-version-from-binary.sh

.PHONY: validate
validate:
	@if [ "x" = "x$(RPI_MODEL)" ]; then \
		echo "ERROR: Unrecognized Raspberry Pi model. Run 'make RPI_MODEL=<model>' if you know which RPi you compiled for."; \
		./venv/bin/rpi-hw-info; \
		exit 1; \
	fi

.PHONY: clean-rpi-hw-info
clean-rpi-hw-info:
	rm -rf venv

.PHONY: clean
clean:
	rm -rf target

endif 