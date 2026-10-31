# jsm/

Declared desired state of the parts of the asset-treatment service that have no public write API.
An operator builds or imports each one by hand in the console. Whether the engine can then check it
depends on whether Jira will report it back.

- `asset-workflow.yaml` — a **control**. Jira reports workflows (`/rest/api/3/workflow/search` with
  `expand=transitions,statuses`), so `asset_workflow_gaps` names every status and transition
  declared here that the tenant does not have. Change this file and the control reports the
  difference until the console work matches.
- `automation-rules.json` — a **step** in `policy/unchecked.yaml`. Jira exposes no read for
  automation rules, so nothing can compare this file with the tenant. Changing it changes what an
  operator must import, and nothing confirms they did.

Nothing here is attested. An earlier design recorded each file's sha256 and compared it with the
file on disk, which only ever proved the file had not changed since someone said they had imported
it — the tenant never entered the comparison, so a rule edited in the console was invisible.

Everything else in the service (project, Asset issue type, fields, request types) is provisioned by
`stages/foundation/treatment.tf`.
