# jsm/

Declared desired state of the parts of the asset-treatment service that have no public write API.
`policy/treatment.yaml` lists them under `imports`. An operator builds or imports each one by hand
and records an attestation with the file's sha256:

```yaml
- { id: automation_rules, kind: attestation, recorded: 2026-10-24T15:00:00Z, by: USER-LAB-ADMIN, sha256: "<sha256sum jsm/automation-rules.json>" }
```

The foundation compares the recorded hash with the file in the repository; a change to the file
fails the control until the import is repeated and re-recorded. Everything else in the service
(project, Asset issue type, fields, request types) is provisioned by `stages/foundation/treatment.tf`.
