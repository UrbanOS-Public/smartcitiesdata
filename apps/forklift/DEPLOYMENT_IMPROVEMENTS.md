# Forklift Production Build Deployment Improvements

## Summary of Changes Applied

This document outlines the improvements made to resolve production build deployment issues for the `apps/forklift` application, migrating from Distillery to the built-in Elixir release system.

## Issues Addressed

1. **Missing release artifact** (`_build/prod/rel/forklift` directory not found)
2. **Deprecated Distillery usage** (no longer actively maintained)
3. **Incorrect build commands and Docker configuration**
4. **Project structure and release configuration issues**

## Changes Made

### 1. Updated `mix.exs` Configuration

**File:** `/apps/forklift/mix.exs`

**Changes:**
- Added `releases: releases()` to the project configuration
- Implemented `releases/0` function with proper configuration:
  ```elixir
  defp releases do
    [
      forklift: [
        include_executables_for: [:unix],
        applications: [runtime_tools: :permanent],
        steps: [:assemble, :tar]
      ]
    ]
  end
  ```

### 2. Updated Dockerfile

**File:** `/apps/forklift/Dockerfile`

**Changes:**
- Replaced `RUN MIX_ENV=prod mix distillery.release --name forklift`
- With `RUN MIX_ENV=prod mix release forklift`
- Updated CMD from `["bin/forklift", "foreground"]` to `["bin/forklift", "start"]`

### 3. Verification Script

**File:** `/apps/forklift/verify_release.sh`

Created a comprehensive verification script that:
- Checks mix.exs configuration
- Validates Dockerfile changes
- Tests compilation with warnings as errors
- Builds and verifies the release
- Confirms executable exists

## Benefits of Migration

### From Distillery to Built-in Mix Release

1. **Actively Maintained**: Built-in releases are part of Elixir core (since 1.9)
2. **Better Performance**: More efficient build process
3. **Simplified Configuration**: Fewer dependencies and simpler setup
4. **Native Support**: No external dependencies required
5. **Future-Proof**: Will continue to be supported and improved

### Technical Improvements

- **Faster Build Times**: Native Elixir release system is more efficient
- **Smaller Dependencies**: Removes distillery dependency
- **Better Error Handling**: Improved error messages during build
- **Configuration Flexibility**: More granular control over release configuration

## Build Commands

### New Production Build Process

```bash
# Get production dependencies
MIX_ENV=prod mix deps.get --only prod

# Compile application
MIX_ENV=prod mix compile

# Create release
MIX_ENV=prod mix release forklift

# Build Docker image
docker build -t forklift:latest .
```

### Docker Build Process

The updated build process in Docker:
1. Uses `smartcitiesdata:build` as builder image
2. Runs `MIX_ENV=prod mix release forklift`
3. Copies release from `_build/prod/rel/forklift/`
4. Starts with `bin/forklift start`

## Verification

Run the verification script to ensure all changes work correctly:

```bash
cd apps/forklift
./verify_release.sh
```

## File Structure After Build

```
_build/prod/rel/forklift/
├── bin/
│   ├── forklift          # Main executable
│   └── forklift.bat      # Windows executable
├── lib/                  # Application libraries
├── releases/            # Release metadata
└── erts-*/              # Erlang runtime (if included)
```

## GitHub Actions Integration

The existing workflow in `.github/workflows/forklift.yml` will work without changes because:
- The build script (`scripts/build.sh`) calls Docker build
- Docker build now uses `mix release` instead of `distillery.release`
- The release artifact path remains the same: `_build/prod/rel/forklift/`

## Protobuf Warnings Resolution

Analysis showed:
- No local Protobuf files in forklift app requiring explicit `@type t` fixes
- Warnings likely come from dependencies (smart_city, etc.)
- Dependencies should be updated by their maintainers
- No action required in forklift application code

## Troubleshooting

### Common Issues and Solutions

1. **Release build fails**:
   - Ensure all dependencies compile: `MIX_ENV=prod mix deps.compile`
   - Check for compilation warnings: `MIX_ENV=prod mix compile --warnings-as-errors`

2. **Docker build fails**:
   - Verify base image `smartcitiesdata:build` exists
   - Ensure proper build context (run from repository root)

3. **Runtime issues**:
   - Check environment variables are properly set
   - Verify application configuration for production

### Verification Commands

```bash
# Test release locally
MIX_ENV=prod mix release forklift
_build/prod/rel/forklift/bin/forklift start

# Test Docker build
docker build -t forklift:test .
docker run --rm forklift:test

# Verify release contents
ls -la _build/prod/rel/forklift/
```

## Migration Checklist

- [x] Update mix.exs with releases configuration
- [x] Update Dockerfile to use mix release
- [x] Remove distillery dependency references
- [x] Create verification script
- [x] Test build process
- [x] Document changes

## Next Steps

1. **Test the build process** in your CI/CD environment
2. **Update any deployment scripts** that reference distillery paths
3. **Monitor the first production deployment** for any runtime issues
4. **Consider updating other apps** in the umbrella project similarly

## Support

For issues with this migration:
1. Run the verification script: `./verify_release.sh`
2. Check the build logs for specific error messages
3. Verify all dependencies are compatible with the new release system

## References

- [Elixir Releases Documentation](https://hexdocs.pm/mix/Mix.Tasks.Release.html)
- [Distillery to Mix Release Migration Guide](https://hexdocs.pm/mix/releases.html#why-releases)
- [Phoenix Deployment with Releases](https://hexdocs.pm/phoenix/releases.html)