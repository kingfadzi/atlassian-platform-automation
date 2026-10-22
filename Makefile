PYTHON ?= python3
VENV_PYTHON := .venv/bin/python

.PHONY: bootstrap validate test check check-sources

bootstrap:
	$(PYTHON) -m venv .venv
	$(VENV_PYTHON) -m pip install -r requirements.txt

validate:
	$(VENV_PYTHON) automation/check.py

test:
	$(VENV_PYTHON) -m unittest discover -s tests -p 'test_*.py' -v

check:
	PYTHON="$(VENV_PYTHON)" sh pipelines/check.sh

check-sources:
	@test -n "$(STRATEGY_REPO)" || \
		(printf '%s\n' 'Set STRATEGY_REPO to a local strategy clone'; exit 2)
	$(VENV_PYTHON) automation/check.py --sources "$(STRATEGY_REPO)"
