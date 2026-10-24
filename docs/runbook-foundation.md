# Foundation runbook

Every control in `policy/foundation.yaml` carries `provision: engine | runbook | external`.
`engine` settings are created by `stages/foundation/provision.tf` from policy and read back as facts.
`external` settings belong to another system and are only verified. `runbook` settings have no
public write API: a named operator makes them true once in the admin console and records an
attestation. The attestation is a fact like any other and expires; the control tells you when.

## Recording an attestation

Append to `runtime/<env>/attestations.yaml` (outside Git in anything but the lab):

```yaml
records:
  - { id: native_project_creation_closed, kind: attestation, recorded: 2026-10-24T15:00:00Z, by: USER-LAB-ADMIN }
```

`id` is the control id, `recorded` is RFC 3339 in UTC, `by` is an account from `policy/identities.yaml`.
The window (`attested_within_days`) is in the catalogue; when it lapses the control fails and the
products that depend on it are reported as not ready until the step is repeated and re-recorded.
The lab's `runtime/lab/attestations.yaml` is the honest record for the real lab tenant; the stub
spike uses its own fixture under `tests/stub/runtime` and never writes to it.

## Runbook steps

| Control | Where | What to do |
|---|---|---|
| `native_project_creation_closed` | Jira: Settings → System → Global permissions | Remove every group from "Create team-managed projects" so only Jira administrators (the engine's admin group) can create projects. Company-managed creation already requires Jira administration. |
| `native_space_creation_closed` | Confluence: Settings → Global permissions | Grant "Create space" to the engine's group only; remove it from `confluence-users` and any other group. |
| `exceptional_identities_reviewed` | `policy/identities.yaml` | Review each account's owner and scope; update `reviewed` for every account still justified; remove the rest (and their access, out of band). |
| `anonymous_jira_closed`, `anonymous_confluence_closed`, `no_public_scheme_grants`, `public_links_off`, `self_signup_off`, `org_policies_enabled`, `confluence_audit_retention`, `announcement_banner`, `evidence_retrieval`, `alert_routing_tested`, `no_sitewide_browse_grants`, `product_access_by_group` | admin console | As before (see each control's title); most are read from the tenant and need no attestation. |

The two native-creation controls are attested because Jira and Confluence global permissions have
no public read or write API for other users. In the real lab, confirm the Jira global permission key
with `GET /rest/api/3/permissions` and, if a key exists, replace the attestation with a
`mypermissions` probe as a non-admin identity (one fact block in `facts.tf`, one catalogue edit).

## Recovering a provisioned setting removed out of band

The REST provider in use (Mastercard/restapi 3.0.0) does not drop an object from state when the
tenant answers 404 on refresh ([issue 377](https://github.com/Mastercard/terraform-provider-restapi/issues/377)).
A grant, role or scheme deleted by an administrator is therefore detected from the tenant read
(`scheme_grants_match_standards`, `roles_match_standards`, `scheme_per_standard_present`), not from
the plan. Recovery:

```
terraform -chdir=stages/foundation state rm 'module.scheme["restricted-collab-v1"].restapi_object.grant["ADD_COMMENTS:member"]'
terraform -chdir=stages/foundation plan     # exactly one create
```

Then let the pipeline apply it. The spike proves this path (`tests/spike.sh`, "[provision]").
The `state rm` is the operator's investigation step the gate's `drift.delete_blocks` rule asks for;
nothing else is touched, and `prevent_destroy` and the gate still refuse every delete, update and replace.
