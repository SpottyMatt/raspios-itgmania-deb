DISTRO := $(shell dpkg --status tzdata|grep Provides|cut -f2 -d'-')
ARCH := $(shell dpkg --print-architecture)
RPI_MODEL = $(shell ./venv/bin/rpi-hw-info 2>/dev/null | awk -F ':' '{print $$1}' | tr '[:upper:]' '[:lower:]' )

ifeq ($(RPI_MODEL),3b+)
# RPI 3B and 3B+ are the same hardware architecture and targets
# So we don't need to generate separate packages for them.
# Prefer the base model "3B" for labelling when we're on a 3B+
RPI_MODEL=3b
endif

PACKAGE_NAME = itgmania-$(RPI_MODEL)

# Fix: Use find to properly enumerate subdirectories 
SUBDIRS := $(shell find $(ARCH) -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

PAREN := \)

.EXPORT_ALL_VARIABLES:

ifeq ($(wildcard ./venv/bin/rpi-hw-info),)
all: rpi-hw-info-setup
	$(MAKE) all

rpi-hw-info-setup:
	python3 -m venv venv
	./venv/bin/pip install --upgrade pip
	./venv/bin/pip install rpi-hw-info==2.0.4
	@ if ! [ -e ./venv/bin/rpi-hw-info ]; then echo "Failed to install rpi-hw-info. Check Python and pip setup."; exit 1; fi

%: rpi-hw-info-setup
	$(MAKE) $@

else

all: $(SUBDIRS)
$(SUBDIRS): target/itgmania packages validate
	rm -rf target/$(notdir $@)
	mkdir -p target/$(notdir $@)
	# Fix: Don't use wildcards in rsync paths
	rsync -v --update --recursive $@/ target/$(notdir $@)/
	mkdir -p target/$(notdir $@)/usr/games/$(notdir $@)
	rsync --update --recursive /usr/local/$(notdir $@)/ target/$(notdir $@)/usr/games/$(notdir $@)/
	$(MAKE) $(notdir $@) FULLPATH=$(notdir $@) ITGMPATH=$(notdir $@)
.PHONY: all $(SUBDIRS)

ifdef ITGMPATH
ITGMANIA_VERSION_NUM:=$(shell /usr/local/$(ITGMPATH)/itgmania --version 2>/dev/null | head -n 1 | awk  '{gsub("ITGMania","", $$1); print $$1}')
ITGMANIA_HASH:=$(shell /usr/local/$(ITGMPATH)/itgmania --version 2>/dev/null | head -n 2 | tail -n 1 | awk '{gsub("$(PAREN)","",$$NF); print $$NF}')
ITGMANIA_DATE:=$(shell cd target/itgmania && git show -s --format=%cd --date=short $(ITGMANIA_HASH) | tr -d '-')
ITGMANIA_DEPS:=$(shell ./find-bin-dep-pkg.py --display debian-control /usr/local/$(ITGMPATH)/itgmania)

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
endif

itgmania-%: \
	target/$(FULLPATH)/DEBIAN/control \
	target/$(FULLPATH)/usr/share/doc/$(PACKAGE_NAME)/changelog.Debian.gz \
	target/$(FULLPATH)/usr/share/doc/$(PACKAGE_NAME)/copyright \
	target/$(FULLPATH)/usr/share/lintian/overrides/$(PACKAGE_NAME) \
	target/$(FULLPATH)/usr/games/$(ITGMPATH)/GtkModule.so \
	target/$(FULLPATH)/usr/games/$(ITGMPATH)/itgmania \
	target/$(FULLPATH)/usr/share/man/man6/itgmania.6.gz \
	target/$(FULLPATH)/usr/bin/itgmania
	cd target && fakeroot dpkg-deb --build $(FULLPATH)
	mv target/$(FULLPATH).deb target/itgmania-$(RPI_MODEL)_$(ITGMANIA_VERSION)_$(DISTRO).deb
	lintian target/itgmania-$(RPI_MODEL)_$(ITGMANIA_VERSION)_$(DISTRO).deb

# itgmania symlink on the PATH
target/$(FULLPATH)/usr/bin/itgmania:
	mkdir -p $(@D)
	ln -s ../games/$(ITGMPATH)/itgmania $@

# debian control files get envvars substituted FRESH EVERY TIME
.PHONY: target/$(FULLPATH)/DEBIAN/*
target/$(FULLPATH)/DEBIAN/*:
	cat $(FULLPATH)/DEBIAN/$(@F) | envsubst > $@

# lintian overrides file must be substituted and renamed
target/$(FULLPATH)/usr/share/lintian/overrides/$(PACKAGE_NAME): $(FULLPATH)/usr/share/lintian/overrides/itgmania
	cat $(<) | envsubst > $(basename $@)

# changelog must be substituted and compressed
target/$(FULLPATH)/usr/share/doc/$(PACKAGE_NAME)/changelog.Debian.gz: $(FULLPATH)/usr/share/doc/itgmania/changelog.Debian
	mkdir -p $(shell dirname $@)
	cat $(<) | envsubst > $(basename $@)
	gzip --no-name $(basename $@)

# copyright gets renamed
target/$(FULLPATH)/usr/share/doc/$(PACKAGE_NAME)/copyright: $(FULLPATH)/usr/share/doc/itgmania/copyright
	cp $(<) $@

# manpages must be compressed
target/$(FULLPATH)/usr/share/man/man6/itgmania.6.gz: $(FULLPATH)/usr/share/man/man6/itgmania.6
	gzip --no-name -9 $(basename $@)

# itgmania needs stripping
.PHONY: target/$(FULLPATH)/usr/games/$(ITGMPATH)/itgmania
target/$(FULLPATH)/usr/games/$(ITGMPATH)/itgmania:
	strip --strip-unneeded $@

# GtkModule needs stripping and non-execute
.PHONY: target/$(FULLPATH)/usr/games/$(ITGMPATH)/GtkModule.so
target/$(FULLPATH)/usr/games/$(ITGMPATH)/GtkModule.so:
	strip --strip-unneeded $@
	chmod a-x $@

# clone the itgmania repository so we can get commit information
target/itgmania:
	git clone https://github.com/itgmania/itgmania.git target/itgmania

# Install deb package linter
.PHONY: packages
packages:
	sudo apt-get install -y \
		binutils \
		lintian

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