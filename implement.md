# Pre/Post Implementation Documentation Protocol

## PRE-IMPLEMENTATION: READ DOCS

Before writing any code:

1. **Identify the product** — which of ArogyaSync, LuxySmile, Orascan, or Orascan_H does this task affect?
2. **Read `SYSTEM_DOCS.md`** in the product root — find the section for the page/feature being changed. Note any Known Issues, recent changes, and architectural context.
3. **Read `ROUTE_REFERENCE.md`** in the product root — find the route, component, API endpoint, and database tables involved.
4. **If ArogyaSync cross-service change:** also read `ArogyaSync_Documentation_Hub/SOURCE_OF_TRUTH.md` and the relevant repo's `SPEC.md`.
5. **If Orascan_H BLE change:** verify UUIDs match in both `OraScan_H_DeviceCode/` and `OraScan_H_Mobile_App/lib/core/constants/ble_uuids.dart`.

## DURING IMPLEMENTATION

- Use the correct file names, table names, and route paths from the docs — do NOT guess.
- If you find a discrepancy between docs and code, flag it and verify which is correct before proceeding.

## POST-IMPLEMENTATION: UPDATE DOCS

After all code changes are verified:

1. **Update `SYSTEM_DOCS.md`:**
   - Add/update Known Issues for the affected section
   - Set "Last Audited" date to today's date
   - Add one-line entry to "Recent Changes Log" (format: `YYYY-MM-DD — description — files changed`)
2. **Only update `ROUTE_REFERENCE.md`** if routes were added, removed, or renamed
3. **If ArogyaSync cross-service change:** update `SOURCE_OF_TRUTH.md` and relevant `SPEC.md` in the same commit

## RULES

- **NEVER** update doc sections you didn't verify through implementation
- **NEVER** remove Known Issues unless you confirmed the fix in code
- **NEVER** backfill "Last Audited" dates for sections you didn't touch
- **NEVER** guess at table names, file names, or route paths — look them up in the docs first
