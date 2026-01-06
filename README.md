# cf-dev-bootstrap — Codeforward Developer Environment Manager

`cf-dev-bootstrap` is a lightweight, opinionated CLI tool to **standardize and automate local Odoo development environments** at Codeforward.

It is designed to minimize setup time, reduce inconsistency between developers, and remove repetitive manual steps when working on customer Odoo repositories.

The tool uses:
- **git bare clones + worktrees** for efficient Odoo source management
- **uv** for Python version and virtual environment management
- **version-aware configuration templates** for Odoo
- a **single Python CLI** that works both interactively and non-interactively

---

## Quick start

> For setting up a customer specific development environment locally 

### 1. Install prerequisites (once)

Make sure you have:

```bash
python3 --version
git --version
uv --version
```

Install `click`:
`python3 -m pip install --user click`

### 2. Install `cf-dev-bootstrap` (once)

Run this command exactly as-is:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/codeforward-bv/cf-dev-bootstrap/main/install.sh)"
```

After this, the command below should work:

`cf-dev-bootstrap --help`

### 3. Create a workspace

Choose (or create) a folder where you want to work on customer projects, for example:

```bash
mkdir ~/Code
cd ~/Code
```
> Everything cf-dev-bootstrap creates will live inside this folder.

### 4. Set up a customer project (interactive, recommended)

Run:

`cf-dev-bootstrap`

Then choose:

`1) Setup customer dev environment`

You will be asked:
* the Git URL of the customer repo
* whether to install a database
* whether to install demo data

Just follow the prompts.

☕ Grab coffee — first setup may take a few minutes because Odoo Community and Enterprise source code will be cloned as well.

### 5. Start Odoo

After setup finishes, you will have:
* a virtual environment in the repo (`.venv`)
* an Odoo config file next to the repo (`<repo>.conf`)
* the database installed (if you chose yes)

To run Odoo manually:

```bash
<org>/<customer-repo>/.venv/bin/python odoo-bin -c <customer-repo>.conf
```

### 6. Update Odoo sources (optional)

You usually only need to run:

```bash
cf-dev-odoo update-odoo
```

to update Odoo sources, and then (re)start Odoo.

---

## Goals

- One standard way of working for all Codeforward developers
- Fast onboarding to any customer Odoo repository
- Minimal disk usage for multiple Odoo versions
- Explicit, version-aware behavior (Odoo ↔ Python ↔ config)
- No hidden magic: everything lives in your local workspace

---

## What `cf-dev-bootstrap` does

### Setup flow (high level)

When setting up a customer environment, `cf-dev-bootstrap` will:

1. Ensure Odoo source code is available  
   - Uses **bare git clones** for:
     - `odoo/odoo`
     - `odoo/enterprise`
   - Creates **git worktrees** for the 3 latest Odoo versions (e.g. 19.0, 18.0, 17.0)

2. Clone the customer repository  
   - Cloned into `<workspace>/<org>/<repo>`
   - SSH or HTTPS URLs supported

3. Detect Odoo version used by the repo  
   - `.copier-answers.yml` (`odoo_version: 18.0`), if available
   - or fallback: `__manifest__.py` version parsing (`"18.0.1.7.0"` → `18.0`)

4. Determine the correct Python version  
   - Uses `mappings/odoo-python.json`
   - Creates a `.venv` using `uv`

5. Install dependencies  
   - Odoo requirements from:
     ```
     odoo/odoo/<version>/requirements.txt
     ```
   - Repo requirements from:
     ```
     <repo>/requirements.txt
     ```

6. Generate an Odoo configuration file  
   - Uses version-specific template:
     ```
     config/<odoo_version>/odoo.conf.tmpl
     ```
   - Outputs:
     ```
     <repo>.conf
     ```
   - Automatically sets:
     - addons paths (community + enterprise + repo)
     - database name
     - DB connection settings

7. (Optional) Install a local database  
   - Creates / ensures Postgres role
   - Installs selected module (`xx_all` if present, otherwise `base`)
   - Supports demo data

---

## Directory layout

`cf-dev-bootstrap` always works **relative to the directory where it is run**:

```text
<workspace, e.g. ~/Code >/
├─ odoo/
│  ├─ odoo/
│  │  ├─ .git/          # bare clone
│  │  ├─ 19.0/          # worktree
│  │  ├─ 18.0/
│  │  └─ 17.0/
│  └─ enterprise/
│     ├─ .git/
│     ├─ 19.0/
│     ├─ 18.0/
│     └─ 17.0/
│
├─ codeforward-bv/
│  └─ <customer-repo>/
│     ├─ .venv/
│     ├─ xx_all/
│     └─ ...
│
├─ codeforward-bv/<customer-repo>.conf
└─ ...
```

---

## Installation

### One-liner install (recommended)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/codeforward-bv/cf-dev-bootstrap/main/install.sh)"
```

This installs cf-dev-bootstrap into:
`~/.local/bin/cf-dev-bootstrap`

Make sure `~/.local/bin` is on your `PATH`.

---

## Prerequisites
The following must be available on your system:

* `python3`
* `git`
* `uv`
* `psql` (only required if you want database setup)
* Python package: `click`

Install click once:
`python3 -m pip install --user click`

---

## Usage

### Interactive mode (recommended):
`cf-dev-bootstrap`

You will be guided through:
* repo selection
* database options
* module installation

### Non-interactive setup

Useful for automation or repeatable scripts.

```
cf-dev-boostrap setup \
  --repo git@github.com:codeforward-bv/codeforward-odoo.git \
  --non-interactive
```

With database installation:

```
cf-dev-bootstrap setup \
  --repo git@github.com:codeforward-bv/codeforward-odoo.git \
  --db \
  --demo \
  --module xx_all \
  --non-interactive
```

---

## Utilities

### Update Odoo worktrees

Fetch and fast-forward all existing worktrees:
`cf-dev-bootstrap update-odoo`

This:
* fetches all remotes
* updates worktrees with `git pull --ff-only`
* skips detached or divergent worktrees

--- 

## Other

### Configuration files

Python ↔ Odoo mapping

`mappings/odoo-python.json`

```json
{
  "17.0": "3.10",
  "18.0": "3.12",
  "19.0": "3.12"
}
```

This file is required because Odoo does not publish official Python compatibility tables.

### Odoo config templates

Stored per major Odoo version:

```text
config/
├─ 17.0/odoo.conf.tmpl
├─ 18.0/odoo.conf.tmpl
└─ 19.0/odoo.conf.tmpl
```

Template variables:
* `{{ODOO_ADDONS_PATH}}`
* `{{DB_HOST}}`
* `{{DB_PORT}}`
* `{{DB_USER}}`
* `{{DB_PASSWORD}}`
* `{{DB_NAME}}`
* `{{ADMIN_PASSWD}}`

Templates are intentionally simple (string replacement only).

### Design decisions

* No Docker (yet): Lower cognitive overhead, faster iteration, easier debugging.
* Bare clones + worktrees: Minimal disk usage with many Odoo versions.
* uv instead of pyenv/virtualenv: Fast, explicit, reproducible Python environments.
* Single-file Python CLI: Easy to audit, version, and distribute.
* Version-aware by default: Odoo version drives Python version, config template, and dependencies.