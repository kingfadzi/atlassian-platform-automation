TF ?= terraform
PYTHON ?= python3
PY := .venv/bin/python
ENV ?= lab
OUT := .outputs
STAGES := tenancy foundation estate
PHASES := $(shell $(PYTHON) -c "import yaml;print(' '.join(p['id'] for p in yaml.safe_load(open('policy/phases.yaml'))['phases']))" 2>/dev/null)

.DEFAULT_GOAL := help
.PHONY: help status $(PHASES) try deps check fmt validate test clean

help:                           ## the stand-up sequence and where you are in it
	@echo "Stand up and operate the platform. Phases run in the order listed."
	@echo
	@$(PY) -c "import yaml;[print('  make %-13s %s' % (p['id'], p['title'])) for p in yaml.safe_load(open('policy/phases.yaml'))['phases']]" 2>/dev/null \
	  || echo "  (run make deps first)"
	@echo
	@printf '  make %-13s %s\n' status "every phase at once"
	@printf '  make %-13s %s\n' try "the whole platform offline against a stub tenant"
	@printf '  make %-13s %s\n' check "everything the pipeline's validate job runs"
	@printf '  make %-13s %s\n' deps "the local Python environment"
	@printf '  make %-13s %s\n' clean "remove local state, plans and caches"
	@echo
	@echo "ENV=$(ENV). A phase with no state is shown as a checklist."

# Each phase reads the same outputs. Where the configured backend is not initialised, fall back to
# the local state file that `make try` leaves behind: it carries outputs in the same shape.
$(OUT):
	@mkdir -p $(OUT)
	@for s in $(STAGES); do \
	  $(TF) -chdir=stages/$$s output -json > $(OUT)/$$s.json 2>/dev/null \
	    || $(PY) -c "import json,sys;print(json.dumps(json.load(open(sys.argv[1])).get('outputs',{})))" stages/$$s/terraform.tfstate > $(OUT)/$$s.json 2>/dev/null \
	    || echo '{}' > $(OUT)/$$s.json; done

status: $(OUT)                  ## every phase at once
	@$(PY) -m govern.cli status --records records/$(ENV) $(foreach s,$(STAGES),--outputs $(s)=$(OUT)/$(s).json)

$(PHASES): $(OUT)
	@$(PY) -m govern.cli status --phase $@ --records records/$(ENV) $(foreach s,$(STAGES),--outputs $(s)=$(OUT)/$(s).json)

try:                            ## the whole platform offline against a stub tenant
	PATH="$(CURDIR)/.venv/bin:$$PATH" tests/spike.sh $(TF)

deps:                           ## the local Python environment for the gate, tests and stub
	$(PYTHON) -m venv .venv
	$(PY) -m pip install -r requirements.txt

check: fmt validate test        ## everything the pipeline's validate job runs

fmt:
	$(TF) fmt -check -recursive

validate:
	@for s in $(STAGES); do \
	  $(TF) -chdir=stages/$$s init -backend=false -input=false >/dev/null && $(TF) -chdir=stages/$$s validate || exit 1; done

test:
	$(TF) -chdir=tests/intent init -input=false >/dev/null && $(TF) -chdir=tests/intent test
	$(TF) -chdir=modules/control_evaluation init -input=false >/dev/null && $(TF) -chdir=modules/control_evaluation test
	$(PY) -m pytest -q tests/govern

clean:
	rm -rf $(OUT) stages/*/.terraform stages/*/terraform.tfstate* stages/*/backend_override.tf stages/*/plan.* tests/intent/.terraform modules/control_evaluation/.terraform
