# Pipeline contract

CI platform not selected. No runnable GitLab/GitHub deployment pipeline is included.

| Stage | Required behaviour |
| :--- | :--- |
| **Validate** | Check formats, schemas and cross-references; available locally through `make validate`. |
| **Policy** | Load pinned values and current authority; deny unknown/stale inputs; not implemented. |
| **Observe and plan** | Read actual target, managed scope and dependencies; produce a protected scoped plan; not implemented. |
| **Review** | Preserve independent technical review and applicable business/control approval. |
| **Apply** | Recheck target/authority, serialise overlapping operations and apply only declared scope; not implemented. |
| **Verify** | Read back and exercise permitted/denied paths; not implemented. |
| **Record** | Register completion and retain protected evidence; not implemented. |
| **Observe independently** | Schedule drift and collector-health checks without a change merge; not implemented. |

CI artefacts, logs and job locks are not substitutes for evidence retention, external authority or out-of-band change detection. All remote command targets currently exit nonzero.
