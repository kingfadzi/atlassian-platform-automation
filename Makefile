PYTHON ?= python3
VENV_PYTHON := .venv/bin/python

.PHONY: help bootstrap validate test check check-sources status plan apply verify observe

help:
	@printf '%s\n' \
		'bootstrap     Install local development dependencies' \
		'validate      Validate scaffold files and cross-references (offline)' \
		'test          Run offline scaffold tests, not control acceptance' \
		'check         Validate and test' \
		'check-sources Verify pins against STRATEGY_REPO (offline)' \
		'status        Show unconfigured execution status' \
		'plan/apply/verify/observe  Intentionally blocked until implemented'

bootstrap:
	$(PYTHON) -m venv .venv
	$(VENV_PYTHON) -m pip install -r requirements-dev.lock

validate:
	$(VENV_PYTHON) tools/validate.py

test:
	$(VENV_PYTHON) -m unittest discover -s tests -p 'test_*.py' -v

check: validate test

check-sources:
	@test -n "$(STRATEGY_REPO)" || (printf '%s\n' 'Set STRATEGY_REPO to a local strategy clone'; exit 2)
	$(VENV_PYTHON) tools/validate.py --sources "$(STRATEGY_REPO)"

status:
	$(PYTHON) tools/not_configured.py status

plan apply verify observe:
	$(PYTHON) tools/not_configured.py $@
