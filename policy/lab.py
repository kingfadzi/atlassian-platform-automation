"""Embedded lab decisions. Pure functions: no IO, network or implicit clock."""

import hashlib
import json
from datetime import datetime, timezone

CONTROL_REFERENCES = ["AIS-05", "CCC-02", "CCC-04", "DSP-04", "DSP-07", "DSP-15", "IAM-15"]
STANDARD_REFS = {
    "jira_project": "jira-restricted-v1",
    "confluence_space": "confluence-private-v1",
}


class Blocked(ValueError):
    """A required safety or authority condition is not established."""


def require(condition, message):
    if not condition:
        raise Blocked(message)


def digest(value):
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()


def timestamp(value):
    try:
        result = datetime.fromisoformat(value.replace("Z", "+00:00"))
        require(result.tzinfo is not None, "Timestamp needs a timezone")
        return result.astimezone(timezone.utc)
    except (AttributeError, TypeError, ValueError) as error:
        raise Blocked("Missing or invalid timestamp") from error


def current(record, now, status):
    require(record.get("status") == status, "Record is not current/authorised")
    require(
        timestamp(record.get("issued_at")) <= now
        < timestamp(record.get("expires_at")),
        "Record is stale or not yet effective",
    )
    require(
        bool(record.get("actor")) and bool(record.get("evidence_ref")),
        "Record has no actor or evidence reference",
    )


def scope(bindings):
    return {
        "organization_id": bindings["organization"]["id"],
        "site_origin": bindings["site"]["origin"],
        "products": {
            key: value["workspace_id"]
            for key, value in bindings["products"].items()
        },
    }


def assess_inputs(intent, bindings, authority, prerequisites, now):
    require(
        intent["environment"] == "lab" and intent["synthetic"] is True
        and intent["deletion_authorized"] is False,
        "Only isolated synthetic lab operations are permitted",
    )
    require(
        bindings.get("lab_credentials_only") is True,
        "Isolated lab credential declaration is required",
    )
    require(
        bindings["organization"]["ref"] == intent["bootstrap"]["organization_ref"]
        and bindings["site"]["ref"] == intent["bootstrap"]["site_ref"],
        "Logical tenancy binding differs",
    )
    require(
        set(bindings["products"]) == {"jira", "confluence"},
        "Both products must be bound",
    )
    expected_scope = scope(bindings)
    for ref in intent["bootstrap"]["prerequisite_refs"]:
        record = prerequisites.get(ref, {})
        current(record, now, "verified")
        require(record.get("scope") == expected_scope, "Prerequisite scope differs")
        require(
            record.get("method") in {"controlled_manual", "automated", "simulated"},
            "Prerequisite method is unknown",
        )
    for asset in intent["assets"]:
        product = "jira" if asset["kind"] == "jira_project" else "confluence"
        target = bindings["products"][product]
        require(target["ref"] == asset["target_ref"], "Product reference differs")
        require(target["origin"] == bindings["site"]["origin"], "Site differs")
        identities = [target[role]["account_id"] for role in ("admin", "allowed", "denied")]
        require(len(set(identities)) == 3, "Acceptance identities must be distinct")
        for role in ("allowed", "denied"):
            require(bool(target[role].get("baseline_path")), "Product-access baseline missing")
        refs = asset["audience_group_refs"] + asset["configuration"]["admin_group_refs"]
        for ref in refs:
            group = bindings["groups"].get(ref, {})
            require(bool(group.get("id")) and bool(group.get("name")), "Unresolved group")
        require(
            set(asset["audience_group_refs"]).isdisjoint(
                asset["configuration"]["admin_group_refs"]
            ), "Audience and administrator references overlap",
        )
        require(
            len({bindings["groups"][ref]["id"] for ref in refs}) == len(refs),
            "Logical groups alias the same native group",
        )
        if product == "jira":
            require(
                bool(bindings["users"].get(asset["configuration"]["lead_ref"])),
                "Project lead is unresolved",
            )
        else:
            require(
                target.get("permission_model") == "legacy",
                "This MVP qualifies only the legacy Confluence permission path",
            )
        for purpose, ref in asset["authority_refs"].items():
            record = authority.get(ref, {})
            current(record, now, "active")
            require(record.get("scope") == expected_scope, "Authority target scope differs")
            require(
                asset["asset_key"] in record.get("asset_keys", [])
                and record.get("application_ref") == asset["business_application_ref"],
                "Authority asset/application scope differs",
            )
            require(record.get("purpose") == purpose, "Authority purpose differs")
            if purpose == "ownership":
                require(
                    record.get("accountable_owner_id") in bindings["users"].values(),
                    "Accountable owner is unresolved",
                )
            if purpose == "classification":
                require(
                    record.get("classification") == asset["requested_classification"],
                    "Classification differs from supplied authority",
                )
            if purpose == "approval":
                require(
                    STANDARD_REFS[asset["kind"]] in record.get("approved_standards", []),
                    "Asset standard lacks business/control approval",
                )
                for field, refs in (
                    ("audiences", asset["audience_group_refs"]),
                    ("administrators", asset["configuration"]["admin_group_refs"]),
                ):
                    require(
                        sorted(record.get(field, {}).get(asset["asset_key"], []))
                        == sorted(bindings["groups"][ref]["id"] for ref in refs),
                        "Approved native groups differ from declared scope",
                    )


def assess_review(plan, review, inputs, admin_ids, now):
    current(review, now, "approved")
    require(review.get("plan_digest") == digest(plan), "Review is for another plan")
    require(plan["inputs"] == inputs, "Inputs changed after planning")
    require(
        review["actor"] not in admin_ids,
        "Technical reviewer must differ from execution identities",
    )
    # The private lab review record is simulated authority, not a trusted firm system.
    require(review.get("lab_only") is True, "Review must be marked lab-only")
