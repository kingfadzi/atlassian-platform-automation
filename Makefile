TF ?= terraform
PYTHON ?= python3
PY := .venv/bin/python

.PHONY: bootstrap check fmt validate test spike clean

bootstrap:                      ## local Python environment for the gate, tests and stub
	$(PYTHON) -m venv .venv
	$(PY) -m pip install -r requirements.txt

check: fmt validate test        ## everything the pipeline's validate job runs

fmt:
	$(TF) fmt -check -recursive

validate:
	@for s in tenancy foundation estate; do \
	  $(TF) -chdir=stages/$$s init -backend=false -input=false >/dev/null && $(TF) -chdir=stages/$$s validate || exit 1; done

test:
	$(TF) -chdir=tests/intent init -input=false >/dev/null && $(TF) -chdir=tests/intent test
	$(TF) -chdir=modules/control_evaluation init -input=false >/dev/null && $(TF) -chdir=modules/control_evaluation test
	$(PY) -m pytest -q tests/govern

spike:                          ## tenancy, foundation and estate against the stub tenant: drift, recovery, estate findings, refusals
	PATH="$(CURDIR)/.venv/bin:$$PATH" tests/spike.sh $(TF)

clean:
	rm -rf stages/*/.terraform stages/*/terraform.tfstate* stages/*/backend_override.tf stages/*/plan.* tests/intent/.terraform modules/control_evaluation/.terraform
