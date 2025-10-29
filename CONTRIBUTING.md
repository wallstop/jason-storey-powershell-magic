# Contributing to PowerShell Magic

Thanks for your interest in improving PowerShell Magic! 🙌 The project thrives
on community feedback and pull requests. This document outlines how to get
started quickly and how to keep the automation happy.

## 📋 Prerequisites

- PowerShell 7.0 or later.
- Git and a GitHub account.
- Optional but recommended: the PowerShell Magic development environment via
  `.\Setup-PowerShellMagic.ps1`.

## 🛠️ Local Setup

1. Fork the repository and clone your fork.
2. Install Git hooks/formatting helpers:

   ```powershell
   .\Setup-Hooks.ps1
   ```

3. Run the formatter and full test suite to make sure the baseline is clean:

   ```powershell
   pwsh -NoProfile -File .\Format-PowerShell.ps1 -Fix
   pwsh -NoProfile -File .\Run-Tests.ps1 -CI
   ```

## 🔄 Branch & Commit Guidelines

- Use descriptive branch names, e.g. `feature/templater-variables` or
  `fix/unitea-sync-warning`.
- Follow the commit style outlined in the README – short imperative messages
  such as `Fix Unitea version drift warning`.
- Keep commits focused; prefer several small commits over one giant change.

## ✅ Testing & Validation Checklist

Before submitting a pull request, please make sure that:

- `pwsh -File .\Run-Tests.ps1 -CI` succeeds.
- `pwsh -File .\Scripts\Run-PreCommit.ps1` reports no unfixable issues.
- New or modified commands include help metadata and, when appropriate,
  regression tests under `Tests/`.
- Documentation updates accompany user-visible changes.

## 🤝 Opening a Pull Request

1. Push your branch and open a PR against `main`.
2. Fill out the PR template with a summary, testing notes, and any screenshots
   or transcripts that clarify behavioural changes.
3. Be responsive to review feedback – small follow-up commits are perfect for
   addressing comments.

## 💬 Getting Help

Questions, ideas, or blocker reports are welcome via
[GitHub issues](https://github.com/wallstop/jason-storey-powershell-magic/issues).

We appreciate every contribution – whether it is code, documentation, or bug
triage. Thanks again for helping make PowerShell Magic better! ✨
