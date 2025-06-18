# ITGMania Debian Package Build Task List

## Research & Analysis
- [x] Examine `raspbian-stepmania-deb` structure and files
- [x] Understand the build process and file organization
- [x] Identify files that need to be updated for ITGMania

## Implementation Plan
- [x] Create directory structure for `raspios-itgmania-deb`
  - [x] Create `armhf/itgmania-1.0` directory and subdirectories
  - [x] Set up DEBIAN control files
  - [x] Set up usr/share documentation files
  - [x] Set up usr/share/man files
  - [x] Set up usr/share/lintian overrides
- [x] Copy and adapt `find-bin-dep-pkg.py` script
- [x] Create and adapt Makefile for ITGMania
- [x] Set up git submodules for rpi-hw-info
- [x] Create deb-build.sh script based on binary-build.sh

## Testing & Verification
- [x] Verify directory structure is correct
- [x] Verify all files have proper content and substitutions
- [ ] Test build script locally
- [ ] Document any potential issues or questions

## Completion
- [x] Final review of all files
- [x] Commit changes to repository
- [ ] Test remote build on famipi 