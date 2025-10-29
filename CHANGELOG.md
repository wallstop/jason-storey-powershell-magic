# Changelog

All notable changes to this project will be documented in this file. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.1.0] - 2025-10-29

### Added

- Documented gallery packaging strategy and introduced the build automation
  scaffold (docs/publishing.md, Scripts/Build-Modules.ps1).
- Added GitHub Actions packaging workflow (.github/workflows/package.yml) that
  packages modules, uploads artifacts, and publishes on tagged releases when
  PSGALLERY_API_KEY is configured.
- Build automation prunes docs/tests from staged module content before
  packaging.
- Added `build/version.json` as the single source of truth for release
  versioning.
- `Scripts/Build-Modules.ps1` now stages modules, updates manifests, and
  produces local nupkg packages for QuickJump, Templater, and Unitea.

### Changed

- README documentation table now references the publishing guide for packaging
  details.

## [1.0.0] - 2025-10-01

- Initial migration of QuickJump, Templater, and Unitea modules into a unified
  repository.
- Established testing, formatting, and setup automation.
