#!/bin/bash
set -e

echo "Finalizing development environment..."

# Setup pre-commit hooks if config exists
if [ -f ".pre-commit-config.yaml" ]; then
    echo "Setting up pre-commit hooks..."
    ~/.local/bin/pre-commit install || true
fi

# Setup Git hooks using project script
if [ -f "Setup-Hooks.ps1" ]; then
    echo "Setting up Git hooks..."
    pwsh -NoProfile -File Setup-Hooks.ps1 || true
fi

echo ""
echo "=========================================="
echo "  PowerShell Magic Dev Environment Ready"
echo "=========================================="
echo ""
echo "Available commands:"
echo "  ./Run-Tests.ps1              - Run all tests"
echo "  ./Run-Tests.ps1 -Test        - Run unit tests only"
echo "  ./Run-Tests.ps1 -Format      - Check formatting only"
echo "  ./Format-PowerShell.ps1      - Format PowerShell files"
echo "  ./Format-PowerShell.ps1 -Fix - Auto-fix formatting issues"
echo "  ./Setup-Hooks.ps1            - Setup Git hooks"
echo ""
