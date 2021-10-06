# OCA

## Purpose

This repo contains:
- some guidelines to work efficiently on OCA modules
- some helpers, especially `oca.sh`

## Requirements

- Working in the dev docker image OR in a Ubuntu
- PG must be running

## Installation

Install `oca.sh` in a dedicated python3 venv as follow:

```
pew new oca -ppython3
pip install https://packages.trobz.com/oca
```

Use `pew workon oca` when working on OCA modules.

## Setup a dev environment

### Retrieve code

- OCA modules are spread across many repositories, often inter-dependant; it's easy to get lost
- Here is a simple way to organize things:

```
~/code: your main code directory
├── odoo: odoo SA's upstream code
│   └── odoo
|       ├── 12.0
|       ├── 13.0
|       └── 14.0
|── oca: oca repositories
│   └── server-tools
|       ├── 12.0
|       ├── 13.0
|       └── 14.0
(...)
```

- to pull a first set of important OCA repos:

```
cd ~/code/oca
oca.sh pull "queue sale-workflow purchase-workflow server-tools server-ux"
```

### Installing odoo

When working on OCA modules, we don't use our usual internal tools (emoi, remoteoi) as we don't want anything Trobz-specific to interfere in the process.

The suggested approach here is to rely on one virtual environment per odoo version:
```
venv-odoo12
venv-odoo13
venv-odoo14
(...)
```

Here is how to install and run odoo in one of these venvs:

```
pew new venv-odoo14 -p python3
pip install -e file:///opt/openerp/code/odoo/odoo/14.0#egg=odoo
pip install -r ~/code/odoo/odoo/14.0/requirements.txt
```

## Configuration

### oca.sh

- In your `~/code/oca` folder, create a `config.sh` file, based on the content of `config.sh.sample`

#### Camptocamp projects example

Camptocamp projects are heavily relying on oca modules, with some customizations. We can run them with `oca.sh` with a few changes in the configuration, for example for the cosanum case, assuming that the project code has been cloned in `/opt/openerp/code/camptocamp/cosanum_odoo`:

```
OCA_ROOT_DIR="/opt/openerp/code/camptocamp/cosanum_odoo/odoo/external-src"
OCA_ROOT_DIR_MODE="repo_module"
EXTRA_ADDONS_PATH="/opt/openerp/code/camptocamp/cosanum_odoo/odoo/local-src"
DB=v14e_cosanum
VENV=venv-odoo14-cosanum
```

### github/travis

- Fork the OCA repos you will be working on in your own github account
- Sign up to Travis with your github account: https://app.travis-ci.com/signup
- Connect your forks with travis: https://travis-ci.com/account/repositories
- Push your branch to your fork first to make sure travis builds are green before pushing to OCA

## Commands

### Trying a module

	oca.sh try queue_job 13.0

This will run odoo 13 with all the OCA modules in the addons path, and install `queue_job` in a dedicated database.

If you are in the module directory already, you can run:

	oca.sh try this

OR

	oca.sh try .

### Run tests of a module

	oca.sh tests queue_job 13.0

This will run odoo 13, and launch tests of queue_job.

Better run the `try` command before running tests, so that the db would be created already.

### Check dependencies of a module

	oca.sh deps queue_job

### Trying a non-merged module

	oca.sh pull-pr https://github.com/OCA/credit-control/pull/146 14.0
	oca.sh try account_invoice_overdue_reminder 14.0
