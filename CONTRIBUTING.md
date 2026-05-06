# Contributing

Thanks for helping improve this Azure Policy solution for SQL Arc license automation.

This repo is intentionally lightweight, so contributions should stay practical: small, clear changes that are easy to review and validate.

## 1) Fork and clone

1. Fork this repository on GitHub.
2. Clone your fork locally.
3. Create a branch for your change.

```powershell
git clone https://github.com/<your-user>/azure-sql-license-policy.git
cd azure-sql-license-policy
git checkout -b feat/<short-description>
```

## 2) Branch naming

Use short, descriptive names:

- `feat/<short-description>` for new behavior
- `fix/<short-description>` for bug fixes
- `docs/<short-description>` for documentation updates

Examples:

- `feat/exclude-existing-payg`
- `fix/assignment-scope-handling`
- `docs/remediation-usage`

## 3) Azure Policy coding/style expectations

Keep policy and script changes consistent with existing patterns:

- Use valid, readable JSON structure in `policy/azurepolicy.json` with stable key ordering where practical.
- Prefer explicit parameter names and clear metadata descriptions.
- Keep parameter names camelCase in policy (`targetLicenseType`, `overwriteExistingLicenseType`) and PowerShell-style in scripts (`TargetLicenseType`).
- Reuse existing naming conventions for definitions/assignments/remediation names.
- Avoid adding policy complexity unless it solves a concrete use case.
- When adding a policy parameter, wire it end-to-end:
	- `policy/azurepolicy.json`
	- `scripts/deployment.ps1`
	- `README.md` (usage and behavior)

## 4) Testing (keep it light)

No heavy test framework required. Before opening a PR, do basic validation:

- Confirm `scripts/deployment.ps1` and `scripts/start-remediation.ps1` parse in PowerShell.
- Confirm `policy/azurepolicy.json` is valid JSON.
- Manually validate behavior in an Arc-enabled SQL Server environment when your change affects policy logic.
- Run a quick compliance check/remediation verification to confirm expected outcomes.

The goal is confidence, not ceremony.

## 5) Submit a pull request

Push your branch to your fork:

```powershell
git push -u origin <your-branch>
```

Open a PR from your fork branch into `claestom:main`.

Please include:

- What changed
- Why it changed
- How you validated it (short notes are enough)

If relevant, link an issue in the PR body (for example, `Closes #3`).
