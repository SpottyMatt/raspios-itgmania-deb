# ITGMania Debian Package Strategy

Analysis and implementation of the ITGMania Debian packaging system, addressing installation directory strategy and version detection.

## Completed Tasks

- [x] Analyzed StepMania's `-5.1` suffix usage pattern
- [x] Confirmed ITGMania installs to `/usr/local/itgmania` (no version suffix)
- [x] Identified potential build vs user installation conflicts

## In Progress Tasks

- [ ] Analyze installation directory strategy options
- [ ] Determine optimal build location to avoid conflicts
- [ ] Design version detection mechanism for packaging

## Future Tasks

- [ ] Update deb packaging structure to match ITGMania conventions
- [ ] Implement version extraction for package naming
- [ ] Test packaging workflow end-to-end

## Implementation Plan

### Installation Directory Strategy Analysis

**Current Situation:**
- ITGMania installs to `/usr/local/itgmania` (no version suffix)
- Our build system currently uses `BASE_INSTALL_DIR=/usr/local`
- Potential conflict with user's own ITGMania builds

**Options to Consider:**
1. **Standard Location (`/usr/local/itgmania`)** - Simple, matches ITGMania defaults
2. **Staging Location (`/tmp/itgmania-staging`)** - Avoid conflicts, copy to package
3. **DESTDIR Approach** - Use GNU Make conventions for staged installs
4. **Custom Build Location** - Build to `/opt/itgmania-build` or similar

### Key Questions
- Should we avoid conflicts with user builds?
- What's the standard practice for package building?
- How do other projects handle this?

### Relevant Files

- `raspios-itgmania-build/Makefile` - Build system configuration
- `raspios-itgmania-deb/Makefile` - Packaging system (needs updating)
- `raspios-itgmania-deb/arm64/itgmania-1.0/` - Package template structure 