# Task List: Migrate rpi-hw-info from Submodule to PyPI Package (raspios-itgmania-deb)

## Overview
Replace git submodule dependency with PyPI package installation in isolated venv for the raspios-itgmania-deb project

## Tasks

### 1. Setup and Preparation
- [x] Create venv-based installation system in Makefile
- [x] Update all rpi-hw-info invocations to use venv binary
- [x] Test venv installation and tool functionality

### 2. Remove Submodule Infrastructure  
- [x] Remove rpi-hw-info submodule from .gitmodules
- [x] Remove rpi-hw-info directory
- [x] Update .gitignore to exclude venv directory

### 3. Documentation Updates
- [x] Update README.md to reflect PyPI installation approach
- [x] Remove submodule references from documentation

### 4. Validation
- [x] Test full build process with new approach
- [x] Verify hardware detection still works correctly
- [x] Ensure clean repository state

## Dependencies
- Python 3.8+ (standard on RaspberryPi OS)
- rpi-hw-info==2.0.4 from PyPI

## Benefits
- No git submodule complexity
- Version pinning for reproducible builds  
- Faster setup (no git operations)
- Cleaner repository structure
- Consistent with raspios-itgmania-build approach 