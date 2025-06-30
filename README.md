# ITGMania Binaries for Raspberry Pi

These scripts can build `.deb` binary packages to install ITGMania on a Raspberry Pi.
This repository's [releases](https://github.com/spottymatt/raspios-itgmania-deb/releases/)
hosts some pre-built ITGMania binaries.

There is a lot more required to make ITGMania actually _playable_ on a Raspberry Pi.
If all you want to do is play ITGMania, check out
[`raspios-itgmania-build`](https://github.com/spottymatt/raspios-itgmania-build) instead.

1. [Download Binaries](#download-binaries)
	1. [Installation Instructions](#installation-instructions)
2. [Building Binaries](#building-binaries)

## Download Binaries

Head over to the [releases](https://github.com/spottymatt/raspios-itgmania-deb/releases).

### Installation Instructions

1. Download the correct `.deb` package for your Raspberry Pi OS distribution & Raspberry Pi hardware
	* You run `cat /etc/os-release` and look for the `VERSION_CODENAME` to check the Raspberry Pi OS distro
	* Hopefully you know which Raspberry Pi you have!
2. Run `sudo apt-get install -f ./itgmania.deb`
3. Done!

## Building Binaries

This tooling builds `.deb` packages of ITGMania binaries for distribution to Raspberry Pi systems.
It should be used on a Raspberry Pi system that has successfully compiled ITGMania from source.

### Pre-Requisites

1. Your Raspberry Pi system has successfully [compiled ITGMania from source](https://github.com/spottymatt/raspios-itgmania-build).
2. Your Raspberry Pi system uses `dpkg` to manage packages.
3. You are able to clone from GitHub.com

### Usage

1. Ensure that `/usr/local` contains an `itgmania` directory from successful compilation of ITGMania
	1. This path is not configurable; if you compiled ITGMania somewhere else, copy it to `/usr/local`
2. Run `make`
3. A binary package will be generated in the `target` directory for the `/usr/local/itgmania/itgmania` binary you compiled

### Versioning

Packages will be named following the pattern

	itgmania-RPI-MODEL_VERSION_DATE_DISTRO.deb

For example, if you built ITGMania 1.0.2, as it stood on June 30 2025, and packaged it with this tool on a Raspberry Pi 4B, you would get

	itgmania-4b_1.0.2_20250630_bookworm.deb

The version number, source control revision, and revision date used in the binary package
will be determined automatically by looking at the `itgmania` binary that you compiled.

The Raspberry Pi model will be determined by the [rpi-hw-info](https://pypi.org/project/rpi-hw-info/) PyPI package.

If you want to package and distribute a different version, just compile a different version first!

By default, all binary packages will be labelled with a `YYYY-MM-DD` datestamp.

If you are packaging a "real release" of ITGMania,
run `make RELEASE=true` to generate the packge with just a version number, e.g.

	itgmania-4b_1.0.2_bookworm.deb 
