# Policy boundary

**No executable policy is implemented yet.** The profile supplies parameter data, not a rule interpreter.

- Select a maintained engine before adding executable rules; do not invent a YAML policy language.
- Admission, change, access and exception packages must return scoped decisions with parent CCM IDs, profile revision and reason codes.
- Revalidate current authority before execution. Schema validation is not an allow decision.
- Add engine-native tests and versioned execution contracts before claiming policy coverage.
