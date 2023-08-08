# OCA

## Purpose

This repo contains:
- some guidelines to work efficiently on OCA modules
- some helpers, especially `oca.sh`

## Requirements

- Working in the dev docker image OR in a Ubuntu
- PG must be running
- [Github Cli](https://cli.github.com) is used for the `oca.sh find` command

## Installation

Install `oca.sh` in a dedicated python3 venv as follow:

```
pew new oca -ppython3
pip install https://packages.trobz.com/oca
```

Use `pew workon oca` when working on OCA modules.

## Configuration

### oca.sh

- In your `~/code/oca` folder, create a `config.sh` file, based on the content of `config.sh.sample`

### github/travis

- Fork the OCA repos you will be working on in your own github account
- Sign up to Travis with your github account: https://app.travis-ci.com/signup
- Connect your forks with travis: https://travis-ci.com/account/repositories
- Push your branch to your fork first to make sure travis builds are green before pushing to OCA

## Setup a dev environment

First follow the recommendations from [odoo.sh](https://gitlab.trobz.com/packages/odoo)

Then you can use `oca.sh` to pull a first set of important OCA repos:

```
cd ~/code/oca
oca.sh pull "queue sale-workflow purchase-workflow server-tools server-ux web"
```

## Commands

### Trying a module

	odoo.sh try queue_job 16.0

This will run odoo 16 with all the OCA modules in the addons path, and install `queue_job` in a dedicated database.

### Run tests of a module

	odoo.sh tests queue_job 16.0

This will run odoo 16, and launch tests of queue_job.

Better run the `try` command before running tests, so that the db would be created already.

### Trying a non-merged module

	oca.sh pull-pr https://github.com/OCA/credit-control/pull/146 14.0
	odoo.sh try account_invoice_overdue_reminder 14.0
