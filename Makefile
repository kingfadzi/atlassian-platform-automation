PYTHON ?= python3
VENV_PYTHON := .venv/bin/python

.PHONY: help bootstrap validate test check check-sources

help:
	@printf '%s\n' \
		'bootstrap     Install development dependencies' \
		'validate      Check configuration and control references (offline)' \
		'test          Test those checks, not control acceptance' \
		'check         Validate and test' \
		'check-sources Verify pins against STRATEGY_REPO (offline)'

bootstrap:
	$(PYTHON) -m venv .venv
	$(VENV_PYTHON) -m pip install -r requirements.txt

validate:
	$(VENV_PYTHON) scripts/check.py

test:
	$(VENV_PYTHON) -m unittest discover -s tests -p 'test_*.py' -v

check: validate test

check-sources:
	@test -n "$(STRATEGY_REPO)" || (printf '%s\n' 'Set STRATEGY_REPO to a local strategy clone'; exit 2)
	$(VENV_PYTHON) scripts/check.py --sources "$(STRATEGY_REPO)"
