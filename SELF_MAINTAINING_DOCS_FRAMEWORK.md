# Orascan — Self-Maintaining Documentation Framework

A framework for maintaining auto-generated, Claude-maintained documentation for Orascan, adapted from the "living docs" pattern.

---

## Documentation Inventory

| Document | Location | Purpose |
|----------|----------|---------|
| `CLAUDE.md` | `Orascan/CLAUDE.md` | Product-level Claude instructions, build commands, repo map |
| `SYSTEM_DOCS.md` | `docs/SYSTEM_DOCS.md` | Human-curated source of truth (auth, dual storage, known bugs) |
| `ROUTE_REFERENCE.md` | `docs/ROUTE_REFERENCE.md` | Auto-generated route-to-component-to-API mapping (~353 lines) |
| `implement.md` | `docs/implement.md` | Pre/post implementation documentation protocol |
| `codebase_analysis.md` | `docs/codebase_analysis.md` | Legacy static analysis (superseded by SYSTEM_DOCS for current state) |
| `architectural_deep_dive.md` | `docs/architectural_deep_dive.md` | Legacy architecture overview (superseded by SYSTEM_DOCS for current state) |

---

## The Two-Document Model

### 1. `SYSTEM_DOCS.md` — Human-curated source of truth
- JWT authentication (Go backend, `golang-jwt/v5`, 3 endpoints only)
- Dual storage architecture (PostgreSQL cloud + MySQL local — **no sync**)
- Desktop app architecture (PyWebView + FastAPI + ReactPy, 13 screens)
- Facemesh CV module status (standalone demos, not integrated)
- Known bugs (no auth guard on `/settings`, no local-cloud sync)
- Recent changes log (last 20 entries)
- **Size target:** ~200-400 lines
- **Who updates:** Claude updates after verified implementation; human reviews monthly

### 2. `ROUTE_REFERENCE.md` — Auto-generated skeleton
- 19 routes across 3 components:
  - Desktop App Screens (13 screens — PyWebView client-side navigation)
  - Backend API (3 Go/Gin endpoints: register, login, upload)
  - Facemesh Module (3 standalone scripts: mouth, tongue, smile)
- Auth requirement per route
- Database tables per endpoint (PostgreSQL cloud + MySQL local)
- Known issues field per entry
- Last audited date per section
- **Who updates:** Regenerated from source code; Claude only updates if routes are added/renamed

---

## Source Files for Regeneration

When regenerating `ROUTE_REFERENCE.md`, Claude should read these entry points:

```
OraScan_Automated_Scanning/main.py            — Desktop app entry point + screen routing
OraScan_Automated_Scanning/app/routes/        — FastAPI route definitions
OraScan_backend/main.go                        — Go/Gin route registrations
OraScan-Facemesh/mouth.py, tongue.py, smile.py — CV module entry points
```

---

## Route Reference Entry Format

```markdown
#### [Screen/Endpoint Name]
- **URL:** `/path` (desktop) or `METHOD /api/path` (backend)
- **Component:** `ScreenName.py` or `handler.go`
- **Access:** Public | JWT Required | No Auth Guard (flag if missing)
- **Backend API:** `METHOD /endpoint` → `handler.go`
- **Database tables:** `table` (PostgreSQL) or `table` (MySQL local)
- **Known issues:** _none_ or bullet list
- **Last audited:** YYYY-MM-DD or _never_
```

---

## Architecture Notes

Orascan has a critical architectural feature: **dual storage with no sync**.
- **Cloud (Go backend → PostgreSQL → Azure Blob):** User accounts + uploaded patient images
- **Local (Desktop app → MySQL):** Offline patient records
- Data entered locally stays local until manually uploaded. If a local device fails, that data is lost.

Any feature that touches data storage must be explicit about which database it targets.

The Facemesh module (`OraScan-Facemesh/`) is currently standalone demos only — not integrated into the scanning workflow. If integrating it, this should be noted as a major architectural change in SYSTEM_DOCS.md.

---

## Maintenance Cadence

| Activity | Frequency | Who |
|----------|-----------|-----|
| Claude reads docs before task | Every session | Automatic (via `/implement` command) |
| Claude updates affected sections | After each implementation | Automatic (via `/implement` command) |
| Human reviews "Last Audited" gaps | Monthly | You |
| Full skeleton regeneration | Quarterly or after major refactor | Claude (prompted) |

---

## Anti-Patterns to Avoid

1. **Don't let Claude backfill sections it didn't verify** — It will confidently write wrong information. Only update sections touched during the current task.
2. **Don't merge SYSTEM_DOCS and ROUTE_REFERENCE** — The route reference is mechanical. The system doc is contextual.
3. **Don't hand-write the skeleton** — Let Claude read the actual source files.
4. **Don't skip git-tracking** — If docs aren't in version control, they drift between environments.
5. **Don't update ROUTE_REFERENCE for non-route changes** — Feature implementations that don't add/remove/rename routes should only touch SYSTEM_DOCS.
6. **Don't confuse the two databases** — Always specify whether a change targets PostgreSQL (cloud) or MySQL (local).
