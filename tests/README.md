# Test scope

`make test` runs offline parser, schema, reference and command-guard checks. Passing these does not establish policy correctness, supported API execution, control effectiveness or compliance.

- **Policy:** engine-native tests will be added after engine selection.
- **Contracts:** scaffold tests exercise structural validity and rejection; no vendor API contracts are tested.
- **Acceptance:** no tenant calls or allowed/denied live operations exist yet.
- **Fixtures:** synthetic records at fixed timestamps; their expiry is not evaluated as live authority.
