# Orascan — System Documentation

> Source of truth for context only a human knows. Claude reads this before every task, updates after verified implementation.

---

## Identity & Auth Architecture

### JWT Authentication
- Go backend (`golang-jwt/v5`) issues tokens on `POST /login`
- Only `POST /upload` requires JWT — the API surface is very small (3 endpoints)
- Rate limiting on `/register` and `/login`

### Desktop App Auth
- Desktop app has its own login/register screens that call the Go backend
- Local session management within PyWebView

## Architecture

### Desktop App (Primary Product)
- Python + FastAPI + ReactPy wrapped in PyWebView (native desktop window)
- 13 screens navigated via client-side `set_current_path()`
- Two variants: `OraScan_Automated_Scanning` (motorized camera) and `OraScan_Manual_Scanning` (manual control)
- Shared utilities in `orascan_common` repo

### Dual Storage — No Sync
- **Cloud (Go backend → PostgreSQL → Azure Blob):** `users` + `patient_images` tables. Images stored in Azure Blob with SAS-token read access.
- **Local (Desktop app → MySQL):** `patient` table for offline patient records.
- **There is NO automatic sync pipeline.** Data entered locally stays local until manually uploaded.

### CV Module (Facemesh)
- 3 standalone scripts: `mouth.py`, `tongue.py`, `smile.py`
- OpenCV + MediaPipe, webcam-based
- Not integrated into the main app as an API — standalone demos only

## Database

### PostgreSQL (Cloud — Go Backend)
| Table | Purpose |
|-------|---------|
| `users` | User accounts (email, password hash, name) |
| `patient_images` | Image metadata + Azure Blob URLs |

### MySQL (Local — Desktop App)
| Table | Purpose |
|-------|---------|
| `patient` | Offline patient records (name, age, gender, phone, email, address) |

## Known Issues

### HIGH Priority
- [ ] `/settings` route has no auth guard — accessible without login
- [ ] No sync between local MySQL and cloud PostgreSQL — data loss risk if local device fails

### MEDIUM Priority
- [ ] Facemesh module is standalone demos, not integrated into scanning workflow
- [ ] Only 3 backend endpoints — very minimal API; may need expansion

### LOW Priority
- [ ] `OraScan_Manual_Scanning` appears to mirror `OraScan_Automated_Scanning` — potential code duplication

## Recent Changes Log

| Date | Change | Files |
|------|--------|-------|
| _initial_ | Auto-generated SYSTEM_DOCS.md, ROUTE_REFERENCE.md, CLAUDE.md | SYSTEM_DOCS.md, ROUTE_REFERENCE.md, CLAUDE.md |

## Deployment Notes

- **Go Backend:** Deployed to cloud, port 3000, PostgreSQL + Azure Blob
- **Desktop Apps:** Distributed as Python packages, run locally on clinic machines
- **Facemesh:** Developer/demo use only

## Existing Documentation

- `docs/codebase_analysis.md` — prior static analysis (may be outdated)
- `docs/architectural_deep_dive.md` — architecture overview (may be outdated)
- These are superseded by this living document for current state.

## Last Full Audit

- **Date:** _never_
- **By:** _pending first human review_
