# PowerShell Magic Publishing Guide

This document captures the emerging plan for distributing the QuickJump,
Templater, and Unitea modules through the PowerShell Gallery (and other package
feeds). It focuses on versioning, manifest hygiene, packaging automation, and
release governance so we can move to repeatable releases under Priority 6 of the
improvement plan.

---

## 🎯 Goals

- Ship each module as an individually installable package while keeping the
  repository as the authoritative source of truth.
- Preserve a single version number across the three modules initially, while
  leaving room for independent lines if module maturity diverges.
- Provide a deterministic build script + CI job that produces signed,
  gallery-ready artifacts (nupkg) after tests and formatting pass.
- Keep publish steps non-interactive for CI, but documented for maintainers when
  a manual hotfix is required.

---

## 🔢 Versioning Strategy

- Adopt semantic versioning across the repo (`MAJOR.MINOR.PATCH`). Begin with
  `1.1.0` once the packaging pipeline lands, reserving `1.0.x` for pre-gallery
  builds.
- Maintain a single version constant in `build/version.json` and sync
  PowerShell manifests (`*.psd1`) via automation so releases stay consistent.
- Increment `PATCH` for bug fixes and doc-only tweaks; bump `MINOR` when
  user-facing functionality ships; bump `MAJOR` only when compatibility breaks.
- Tag releases as `vMAJOR.MINOR.PATCH` in git. CI uses the tag to determine the
  version written into manifests and gallery packages.

---

## 📦 Module Manifest Requirements

- Ensure `RootModule`, `ModuleVersion`, `CompatiblePSEditions`,
  `PowerShellVersion`, and `RequiredModules` are populated for each module
  (`Modules/<Module>/<Module>.psd1`).
- Add `ProjectUri`, `LicenseUri`, `Tags`, and `ReleaseNotes` in
  `PrivateData.PSData` for gallery metadata consistency.
- Export lists (`FunctionsToExport`, `AliasesToExport`) should stay curated per
  module; the gallery `Publish-Module` step relies on them.
- The packaging build will inject the release notes section from `CHANGELOG.md`
  (to be added) into each manifest before packaging.

---

## 🛠️ Packaging Workflow (Draft)

1. **Bootstrap**

   - Run `.\Run-Tests.ps1 -CI` (already covers lint + functional validation).
   - Invoke `Scripts/Build-Modules.ps1` to:
     - Resolve version from `build/version.json` (or tag environment variable
       when CI tags releases).
     - Copy module folders into `out/staging/<Module>` (public/private scripts
       only).
     - Update each `*.psd1` `ModuleVersion` and `ReleaseNotes` using
       `CHANGELOG.md`.

2. **Package**

   - `Build-Modules.ps1` registers a temporary local repository and calls
     `Publish-Module` for each staged module, producing `.nupkg` files under
     `out/packages`.
   - CI can still leverage `Publish-Module -WhatIf` for dry runs or skip gallery
     pushes when secrets are absent.

3. **Artifacts**

   - Publish the resulting `.nupkg` files and `module-metadata.json` (contains
     SHA256 hashes, exports, and release notes) as build artifacts before
     pushing to gallery.

4. **Signing (Future)**
   - If we later sign scripts, integrate `Set-AuthenticodeSignature` before
     packaging; store cert thumbprint in CI secrets.

---

## 🤖 Continuous Integration Outline (package.yml)

- **Trigger:** push/PR on `main`, manual dispatch, and GitHub release
  publications.
- **Steps (per `.github/workflows/package.yml`):**
  1. Checkout repo (`actions/checkout@v4`), retaining full history.
  2. Install `PowerShellGet` (ensures `Publish-Module`/`Publish-PSResource`
     availability).
  3. Run `.\Run-Tests.ps1 -CI`.
  4. Execute `Scripts/Build-Modules.ps1` (dry-run by default; `-Release` is
     implied during release jobs) to stage modules, update manifests, and
     produce packages + metadata.
  5. Validate packages via `Scripts/Test-BuildArtifacts.ps1` to ensure metadata
     hashes match generated nupkg files.
  6. Upload `out/packages/*.nupkg` and `module-metadata.json` as build
     artifacts.
  7. On tagged releases with `PSGALLERY_API_KEY`, publish packages to the
     PowerShell Gallery (uses `Publish-Module`).
- **Rollback:** release jobs only publish when secrets are available; failures
  leave artifacts for manual retry.
- **Manual fallback:** If CI cannot publish, maintainers may run the following:

  ```powershell
  ./Scripts/Build-Modules.ps1 -Release -OutputPath ./out
  Get-ChildItem ./out/packages/*.nupkg |
      ForEach-Object {
          Publish-Module -Path $_.FullName -Repository PSGallery -NuGetApiKey <key>
      }
  ```

  Verify `out/packages/module-metadata.json` and hash outputs before releasing.

---

---

## 🏷️ Release Tagging & Staging Notes

- **Git Tags:** Use semantic tags in the form `vMAJOR.MINOR.PATCH` (for example,
  `v1.1.0`). The packaging workflow only publishes when the release event
  references one of these tags and `PSGALLERY_API_KEY` is configured.
- **Release Branches:** Changes should land on `main`; create GitHub releases
  from the tagged commit after verifying CI artifacts.
- **Staging Contents:** `Scripts/Build-Modules.ps1` copies each module’s root
  `.psm1`, `Public/`, and `Private/` folders while pruning common documentation
  folders (`docs`, `tests`, `examples`) and markdown files. Review staged output
  if new asset types are added.
- **Manual Verification:** Always inspect `out/packages/module-metadata.json`
  (hashes, exports, tags, notes) and `Scripts/Test-BuildArtifacts.ps1` output
  when performing manual releases.

## ✅ Checklist Before Publishing

- [ ] Update `build/version.json` with new version.
- [ ] Mention new features/fixes in `CHANGELOG.md`.
- [ ] Ensure module manifests include updated metadata (automated check will
      fail otherwise).
- [ ] Confirm README/DEVELOPMENT docs reference the new release if workflows
      change.
- [ ] Run `.\Run-Tests.ps1 -CI` locally prior to tagging.
- [ ] Create `git tag vMAJOR.MINOR.PATCH` and push tag to origin.
- [ ] Verify CI workflows (lint + package) complete successfully and review
      generated artifacts before announcing the release.

---

## 🚧 Upcoming Tasks (Tracked in PLAN.md)

- Refine staging exclusions (docs/tests) and support additional asset types if
  needed.
- Validate `module-metadata.json` shape/hashes inside CI before publishing.
- Add documentation for release branch/tag naming once gallery publishing
  succeeds.

This guide will evolve as packaging automation is implemented. See `PLAN.md`
Priority 6 for real-time tracking. Contributions and suggestions are
welcomed—open an issue with the `packaging` label to discuss improvements.
