# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project Overview

`cf-dev-bootstrap` is a CLI tool that automates local Odoo development environment setup at Codeforward. It manages Odoo source code via git bare clones + worktrees, creates Python virtual environments with `uv`, and generates version-aware Odoo configurations.

---

## Quick Reference

| Item             | Value                     |
| ---------------- | ------------------------- |
| Python version   | 3.10+                     |
| Author           | `Codeforward B.V.`        |
| Main dependency  | `click`                   |
| Package manager  | `uv` (for venvs/deps)     |
| Default branch   | `main`                    |
| Odoo versions    | 15.0, 16.0, 17.0, 18.0, 19.0 |

---

## Commands

### Installation

```bash
# One-liner install (fetches from GitHub, sets up ~/.local/bin wrapper)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/codeforward-bv/cf-dev-bootstrap/main/install.sh)"
```

### Usage

```bash
# Interactive menu (recommended)
cf-dev-bootstrap

# Non-interactive setup
cf-dev-bootstrap setup --repo git@github.com:org/repo.git --non-interactive

# Setup with database
cf-dev-bootstrap setup --repo git@github.com:org/repo.git --db --demo --module xx_all --non-interactive

# Setup with specific branch (defaults to "main" if not specified)
cf-dev-bootstrap setup --repo git@github.com:org/repo.git --branch feature-branch

# Update all Odoo worktrees
cf-dev-bootstrap update-odoo

# Add worktree for specific Odoo version
cf-dev-bootstrap add-worktree 15.0
```

---

## Architecture

### Key Files

| File                    | Purpose                                              |
| ----------------------- | ---------------------------------------------------- |
| `cf-dev-bootstrap`      | Main Python CLI script (single-file, ~1400 lines)    |
| `install.sh`            | macOS installer (Homebrew, uv, wrapper setup)        |
| `Brewfile`              | Homebrew dependencies (python, postgresql, uv)       |
| `mappings/odoo-python.json` | Odoo version -> Python version mapping           |
| `config/<version>/odoo.conf.tmpl` | Version-specific Odoo config templates     |

### CLI Structure

The main script uses Click with a group that invokes the interactive menu when no subcommand is given:

- `cli()` - Entry point, shows menu if no subcommand
- `setup_cmd` - `cf-dev-bootstrap setup` subcommand
- `update_odoo_cmd` - `cf-dev-bootstrap update-odoo` subcommand
- `add_worktree_cmd` - `cf-dev-bootstrap add-worktree <version>` subcommand

### Setup Flow

1. **Plan collection** (`collect_setup_plan`) - Gathers all user inputs before heavy work
2. **DB check** - Checks if database exists and prompts for recreation BEFORE cloning
3. **Clone customer repo** - Into `<workspace>/<github-org>/<repo-name>`
4. **Init submodules** - `git submodule update --init --recursive`
5. **Detect Odoo version** - From `.copier-answers.yml` or `__manifest__.py`
6. **Ensure Odoo sources** - Bare clones + worktrees for community and enterprise
7. **Create venv** - Using `uv venv --python <version>`
8. **Install dependencies** - Odoo requirements + repo requirements + external requirements
9. **Generate PyCharm configs** - `.run/Install.run.xml`, `.run/Run.run.xml`, `.run/Unittest.run.xml`
10. **Install pre-commit hooks** - If `.pre-commit-config.yaml` exists
11. **Create Odoo config** - From version-specific template
12. **Install database** - Optional, runs `odoo-bin -i <module>`

### Workspace Layout Created

```
<workspace>/
├── odoo/
│   ├── odoo/
│   │   ├── .git/          # bare clone
│   │   ├── 19.0/          # worktree
│   │   ├── 18.0/
│   │   └── 17.0/
│   └── enterprise/
│       ├── .git/          # bare clone
│       └── <versions>/
├── <github-org>/
│   └── <customer-repo>/
│       ├── .venv/
│       └── .run/
└── <github-org>/<customer-repo>.conf
```

### Asset Management

Assets (mappings, config templates) are downloaded on-demand from GitHub and cached in `~/.local/share/cf-dev-bootstrap/`. The base URL can be overridden via `CF_DEV_BOOTSTRAP_ASSET_BASE_URL` environment variable.

---

## Commit Messages

Follow the standard Codeforward format:

```
[TAG] short summary (max 50 chars)

Longer description explaining why.
```

Tags: `[FIX]`, `[IMP]`, `[ADD]`, `[REM]`, `[REF]`

---

## Dependencies

| Package     | Purpose                                    |
| ----------- | ------------------------------------------ |
| `click`     | CLI framework                              |
| `uv`        | Python version and venv management         |
| `git`       | Bare clones, worktrees, submodules         |
| `psql`      | PostgreSQL role/database management        |
| `pre-commit`| Git hooks (installed globally via uv tool) |

---

## Configuration

### Odoo-Python Version Mapping

Edit `mappings/odoo-python.json` to add/modify Odoo-to-Python version mappings:

```json
{
  "15.0": "3.12",
  "16.0": "3.12",
  "17.0": "3.12",
  "18.0": "3.12",
  "19.0": "3.12"
}
```

### Config Templates

Templates in `config/<version>/odoo.conf.tmpl` use simple `{{VARIABLE}}` substitution:

- `{{ODOO_ADDONS_PATH}}`
- `{{DB_HOST}}`, `{{DB_PORT}}`, `{{DB_USER}}`, `{{DB_PASSWORD}}`
- `{{DB_NAME}}`, `{{ADMIN_PASSWD}}`

---

*Last updated: 2025-01-29*
