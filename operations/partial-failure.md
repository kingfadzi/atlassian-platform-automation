# Partial failure

Not implemented. Stop on uncertain or incomplete application; preserve restricted/unreleased handling.

Record completed/uncertain actions in a protected checkpoint store, re-read actual state, revalidate authority and resume only under the approved execution contract. Do not replay grants blindly or assume a Git revert restores SaaS state.

Unrecoverable or irreversible effects require explicit escalation and gap treatment.
