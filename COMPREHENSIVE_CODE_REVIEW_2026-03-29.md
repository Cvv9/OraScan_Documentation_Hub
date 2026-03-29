# OraScan Comprehensive Code Review

**Date:** 2026-03-29
**Reviewer:** Claude Opus 4.6 (Automated)
**Scope:** Full codebase review across all OraScan components
**Components Reviewed:**
- `OraScan_backend/` — Go/Gin REST API (PostgreSQL, Azure Blob, JWT)
- `OraScan_Automated_Scanning/` — Python desktop kiosk app (FastAPI + ReactPy + PyWebView)
- `OraScan_Manual_Scanning/` — Python manual scanning variant
- `OraScan_Disease_Model_Training/` — ML pipeline (EfficientNet-B0, ONNX)

---

## Review Summary

| Severity     | Count | Key Areas                                                  |
|--------------|-------|------------------------------------------------------------|
| **Blocker**  | 6     | Committed secrets, plaintext PII in local DB, HTTP defaults |
| **High**     | 9     | Missing auth scoping, input validation gaps, thread safety  |
| **Medium**   | 8     | Desync risks, compilation issues, CI gaps                   |
| **Low/Nit**  | 4     | Dead code, hardcoded paths                                  |
| **Praise**   | 5     | Crypto, config validation, tests, ML pipeline               |

**Top 3 Immediate Actions:**
1. **Rotate all secrets** and purge `.env` from git history
2. **Encrypt Aadhaar in local MySQL** the same way the backend does
3. **Default to HTTPS** for all API communication and add `.env` to `.gitignore`

---

## CRITICAL / BLOCKER Findings

### 1. [BLOCKER] Committed Secrets in `.env` — ACTIVE DATA BREACH RISK

**File:** `OraScan_backend/.env:1-5`

**Description:** The `.env` file contains real production credentials committed to the repository:

```
connectdb="host=<AZURE_HOST> user=<DB_USER> password=<REDACTED> ..."
AZURE_STORAGE_ACCOUNT="<REDACTED>"
AZURE_STORAGE_KEY=<REDACTED - REAL BASE64 KEY WAS COMMITTED>
AZURE_CONTAINER_NAME="<REDACTED>"
JWT_SECRET="super-secret-key-change-this-in-production"
```

> **NOTE:** Actual production credentials were committed in this file. All values above have been redacted in this review document. The originals remain in the repository's git history and must be rotated immediately.

This is the single most critical finding. Even if this repo is private, these credentials are in git history permanently. Anyone with repo access has full database and blob storage access.

**Impact:** Full database access, blob storage access, ability to forge JWT tokens.

**Action Required:**
1. Rotate ALL credentials immediately (DB password, Azure storage key, JWT secret, Aadhaar encryption key)
2. Run `git filter-repo` or BFG to purge `.env` from git history
3. Add `.env` to `.gitignore` (verify it's there)
4. Use Azure Key Vault or environment-injected secrets in deployment

---

### 2. [BLOCKER] `.env` Format Mismatch — App Won't Boot with Current `.env`

**File:** `OraScan_backend/.env:1` vs `OraScan_backend/config.go:47-56`

**Description:** The `.env` uses a legacy `connectdb=` connection string format, but `config.go` expects individual `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` vars. The config validation will fail with "missing required environment variables" on startup.

**Impact:** Either the app is running with env vars set externally (bypassing `.env`), or the app cannot currently start at all.

**Fix:** Update `.env` to use individual env vars matching `config.go` expectations:
```env
DB_HOST=orascandb.postgres.database.azure.com
DB_PORT=5432
DB_USER=orascandbowner
DB_PASSWORD=<rotated-password>
DB_NAME=postgres
```

---

### 3. [BLOCKER] Aadhaar (PII) Stored in Plaintext in Local MySQL

**File:** `OraScan_Automated_Scanning/register_page.py:30-33`

**Description:** The registration page inserts Aadhaar directly into the local MySQL database as plaintext:
```python
query = "INSERT INTO patient (..., Aadhar) VALUES (%s, ..., %s)"
cursor.execute(query, (..., aadhar))
```
While the Go backend encrypts Aadhaar with AES-256-GCM, the local kiosk MySQL stores it raw.

**Impact:** Compliance violation (Indian DPDP Act / UIDAI guidelines). Aadhaar must be encrypted at rest everywhere.

**Fix:** Apply AES-256 encryption to Aadhaar before local MySQL storage. Port the encryption logic from `crypto.go` to a Python equivalent, or store only the last 4 digits locally.

---

### 4. [BLOCKER] Plaintext Password Sent to Backend During Registration

**File:** `OraScan_Automated_Scanning/register_page.py:36-44`

**Description:**
```python
backend_payload = {
    ...
    "password": password,  # raw plaintext
}
ok, backend_error = register_user(backend_payload)
```

The raw password is sent over HTTP (not HTTPS by default — `BACKEND_URL` defaults to `http://127.0.0.1:3000`). In any network-accessible deployment, this transmits passwords in cleartext.

**Impact:** Password interception via network sniffing in any non-localhost deployment.

**Fix:** Enforce HTTPS for all backend communication. Change the default `BACKEND_URL` to `https://`.

---

### 5. [BLOCKER] `api_client.py` Uses HTTP by Default

**File:** `OraScan_Automated_Scanning/api_client.py:7`

**Description:**
```python
BACKEND_URL = os.getenv("ORASCAN_BACKEND_URL", "http://127.0.0.1:3000")
```

Default is `http://`, not `https://`. Any deployment beyond localhost will transmit JWT tokens, passwords, and PII in cleartext.

**Impact:** All API traffic (including auth tokens and patient data) transmitted unencrypted.

**Fix:** Change default to `https://` and add TLS certificate validation.

---

### 6. [BLOCKER] `config.py` — MySQL Password Defaults to Empty String

**File:** `OraScan_Automated_Scanning/config.py:5`

**Description:**
```python
"password": os.getenv("ORASCAN_DB_PASSWORD", ""),
```

A passwordless MySQL root account is the default. If the env var is not set, anyone on the network can access the patient database.

**Impact:** Unauthenticated access to patient database containing PII.

**Fix:** Remove the empty string default. Fail explicitly if `ORASCAN_DB_PASSWORD` is not set.

---

## HIGH Severity Findings

### 7. [HIGH] No Input Validation on Registration Fields (Backend)

**File:** `OraScan_backend/api.go:218-238`

**Description:** `RegisterHandler` blindly accepts whatever `ShouldBindJSON` parses. There's no validation for:
- Email format
- Password strength (length, complexity)
- Contact number format
- Empty required fields (FirstName, etc.)

The only validation is on Aadhaar format (in `CreateUser`).

**Fix:** Add `binding:"required,email"` struct tags to `RegisterInput` or add explicit validation in the handler.

---

### 8. [HIGH] No Image Retrieval API — Images Become Inaccessible After SAS Expiry

**File:** `OraScan_backend/api.go:77-82`

**Description:** The API has `/upload` but no `/images` or `/my-images` endpoint. Uploaded images are linked to the user but there's no way to retrieve them via the API. The SAS URL returned at upload time expires in 1 hour. After that, images are inaccessible.

**Fix:** Add a `GET /my-images` endpoint that lists the user's images and generates fresh SAS URLs on demand.

---

### 9. [HIGH] `SyncPatientHandler` — Missing Authorization Scoping

**File:** `OraScan_backend/sync_handler.go:23-66`

**Description:** The handler extracts `userID` from JWT but then looks up a patient by the `email` from the request body — not by the authenticated user's ID. Any authenticated user can probe whether any email exists in the system and trigger sync for any patient.

**Fix:** Validate that the authenticated user is authorized to sync the specified patient (e.g., check that the email matches the JWT user).

---

### 10. [HIGH] `User` Struct Exposes Deprecated Plaintext `aadhar` in JSON

**File:** `OraScan_backend/type.go:27`

**Description:**
```go
Aadhar string `db:"aadhar" json:"aadhar"` // DEPRECATED: Will be removed
```

The `json:"aadhar"` tag means the full plaintext Aadhaar (if it exists from legacy data) will be serialized in any JSON response that returns a `User`.

**Fix:** Change to `json:"-"` to suppress JSON serialization, matching the encrypted field.

---

### 11. [HIGH] `password_utils_old.py` Allows Plaintext Password Comparison

**File:** `OraScan_Automated_Scanning/password_utils_old.py:24-25`

**Description:**
```python
# Legacy plaintext support for in-place migration.
return hmac.compare_digest(stored_value, candidate)
```

This file still exists and its `verify_password` function compares plaintext passwords. While the new `password_utils.py` correctly rejects plaintext, the old file is still importable and could be used accidentally.

**Fix:** Delete `password_utils_old.py`.

---

### 12. [HIGH] Audit Middleware Fire-and-Forget Without Error Tracking

**File:** `OraScan_backend/audit.go:164-169`

**Description:**
```go
go func() {
    err := store.LogAudit(...)
    if err != nil {
        log.Printf("Audit logging failed: %v", err)
    }
}()
```

Audit logs are compliance-critical but failures are silently logged and dropped. There's no retry, no fallback buffer, and no alerting.

**Fix:** Add at minimum a bounded retry with exponential backoff, and consider a local fallback file for audit events when the DB is unavailable.

---

### 13. [HIGH] `main.py` Uses Global Mutable State for Camera/FaceMesh

**File:** `OraScan_Automated_Scanning/main.py:126-127`

**Description:**
```python
cap = None
face_controller = None
```

Global mutable `cap` and `face_controller` are shared across threads (FastAPI/uvicorn is multi-threaded). OpenCV `VideoCapture` is not thread-safe. Concurrent requests to the oral photo page could cause race conditions or crashes.

**Fix:** Use a thread lock around camera access, or ensure single-threaded access via an asyncio queue.

---

### 14. [HIGH] `createPatientFromSync` Would Create Users Without Passwords

**File:** `OraScan_backend/sync_handler.go:76-84`

**Description:** Though commented out, this function creates users with empty passwords and Aadhaar. If uncommented, it would bypass all security (bcrypt of empty string, Aadhaar validation fails).

**Fix:** Remove the function entirely, or properly implement it with required validation.

---

### 15. [HIGH] Docker-Compose CORS Allows `http://` Origins Only

**File:** `OraScan_backend/docker-compose.yml:52`

**Description:**
```yaml
ALLOWED_ORIGINS: http://localhost:5173,http://localhost:3000
```

No HTTPS origins configured. In production, this needs to be tightened to the actual deployment domain over HTTPS.

**Fix:** Use production HTTPS domains in deployment, and remove `http://` localhost entries from production configs.

---

## MEDIUM Severity Findings

### 16. [MEDIUM] `register_page.py` — Dual Registration Creates Desync Risk

**File:** `OraScan_Automated_Scanning/register_page.py:28-48`

**Description:** Registration writes to local MySQL AND calls the backend API. If the backend fails (line 46), the user is still registered locally but not in the cloud — creating a permanent desync with no retry mechanism or user notification.

**Fix:** Add visual feedback to the user when backend sync fails, and queue a retry for background sync.

---

### 17. [MEDIUM] `main.py` — Login Succeeds Even if Backend Fails

**File:** `OraScan_Automated_Scanning/main.py:64-68`

**Description:**
```python
ok, token, backend_error = login_user(email, password)
if not ok:
    print(f"WARN: Backend login failed for {email}: {backend_error}")
    token = ""
```

If the backend is unreachable, login still succeeds (local-only). The user gets `auth_token = ""`, which means all subsequent API calls (upload, sync) will fail with 401. The UX should warn the user explicitly.

**Fix:** Display a visible warning (e.g., "Offline mode — some features unavailable") when backend auth fails.

---

### 18. [MEDIUM] `database_utils.py` — `ensure_*` Functions Called Repeatedly

**File:** `OraScan_Automated_Scanning/database_utils.py:57-68, 148-168`

**Description:** `ensure_h2s_column()`, `ensure_reports_table()`, and `ensure_sync_column()` are called on every related DB operation. Each fires a `SHOW COLUMNS` or `CREATE TABLE IF NOT EXISTS` query.

**Fix:** Run these once at application startup instead of on every operation. Add a startup initialization function.

---

### 19. [MEDIUM] `User.CreatedAt` Referenced but Not in Struct

**File:** `OraScan_backend/sync_handler.go:140`

**Description:**
```go
LastCloudUpdate: user.CreatedAt,
```

The `User` struct in `type.go` has no `CreatedAt` field. This will either not compile, or produce a zero-value `time.Time` (`0001-01-01`).

**Fix:** Add `CreatedAt time.Time` to the `User` struct and include it in the `GetUserByEmail`/`GetUserByID` queries.

---

### 20. [MEDIUM] `PatientImage.ImageNumber` Field Mismatch

**File:** `OraScan_backend/type.go:36`

**Description:** The struct has `ImageNumber int` but the DB table schema has no `image_number` column. The `SaveUserImage` `RETURNING` clause doesn't include it. This field is never populated.

**Fix:** Remove `ImageNumber` from the struct, or add the column to the DB schema if needed.

---

### 21. [MEDIUM] CI Pipeline Gosec Uses `-no-fail`

**File:** `OraScan_backend/.github/workflows/ci.yml:86`

**Description:**
```yaml
args: '-no-fail -fmt sarif -out results.sarif ./...'
```

Security scan never fails the build. Security findings are uploaded to SARIF but won't block a merge.

**Fix:** Remove `-no-fail` to make security findings block PRs, or configure severity thresholds.

---

### 22. [MEDIUM] Rate Limiter Bypass via Proxy/Load Balancer

**File:** `OraScan_backend/middleware.go:104-106`

**Description:** `c.ClientIP()` trusts `X-Forwarded-For` headers by default in Gin. Behind a proxy, an attacker can spoof their IP to bypass rate limiting.

**Fix:** Use `gin.SetTrustedProxies()` to configure trusted proxy IPs explicitly.

---

### 23. [MEDIUM] `store.Close()` Called Twice on Shutdown

**File:** `OraScan_backend/main.go:33, 61`

**Description:**
```go
defer store.Close()  // line 33
...
store.Close()        // line 61 (on signal)
```

The deferred `Close()` will fire after the signal handler's `Close()`, calling `db.Close()` twice. The second call will trigger `log.Fatal` in the `Close()` method.

**Fix:** Remove the explicit `store.Close()` in the signal handler (rely on `defer`), or use `sync.Once` to guard the close operation.

---

## LOW / NITS

### 24. [LOW] `password_utils_old.py` Should Be Deleted

The old PBKDF2 implementation is superseded by `password_utils.py`. Keeping it risks accidental import by future contributors.

---

### 25. [LOW] Hardcoded Dataset Paths in Training Scripts

**Files:** `OraScan_Disease_Model_Training/train_classifier.py:34-35`, `inference.py:26`

```python
DATA_DIR = Path(r"E:\ECG and Dental Images\Dental data set\Training_Ready")
MODEL_DIR = Path(r"E:\ECG and Dental Images\Dental data set\Models")
```

These are machine-specific paths. Use environment variables or command-line arguments.

---

### 26. [LOW] Missing `.gitignore` Verification

Verify `.gitignore` covers `.env`, `captured_images/`, model files (`.pth`, `.onnx`), and `__pycache__/`.

---

### 27. [LOW] Aadhaar Sent in Plaintext to Backend API in Transit

**File:** `OraScan_Automated_Scanning/register_page.py:41`

Even though the backend encrypts Aadhaar on receipt, the transit path should use HTTPS to protect it in flight.

---

## PRAISE / Positive Findings

### 28. Aadhaar Encryption Implementation (Backend)

The AES-256-GCM encryption in `crypto.go` is textbook correct — random nonce, proper key derivation, base64 encoding, and masking for display. Includes comprehensive test coverage with round-trip tests, wrong-key tests, and benchmarks.

---

### 29. Config Validation with Security Checks

`config.go:71-123` catches placeholder JWT secrets and weak keys at startup. This prevents accidental insecure deployments — a pattern many production systems lack.

---

### 30. Comprehensive Test Suite

The Go test files cover encryption round-trips, password hashing verification, rate limiting, duplicate registration, invalid input, and unauthorized access. The crypto benchmarks are a nice touch for performance regression detection.

---

### 31. Security Verification Script

`scripts/verify_security.go` is a well-designed pre-deployment checklist that catches plaintext Aadhaar, weak keys, missing configs, and incomplete migration. This should be integrated into CI/CD.

---

### 32. ML Pipeline Quality

The training pipeline handles class imbalance correctly (WeightedRandomSampler), uses proper two-phase training (frozen backbone then fine-tune), and exports to ONNX with verified DirectML inference. The 96.4% validation accuracy across 11 classes is strong.

---

## Recommendations by Priority

### Immediate (Before Next Deployment)
1. Rotate all committed secrets (DB, Azure, JWT, Aadhaar key)
2. Purge `.env` from git history with `git filter-repo`
3. Add `.env` to `.gitignore` across all repos
4. Change `json:"aadhar"` to `json:"-"` in `type.go`
5. Delete `password_utils_old.py`

### Short-Term (Next Sprint)
6. Encrypt Aadhaar in local MySQL (match backend encryption)
7. Default all API URLs to HTTPS
8. Add input validation to `RegisterHandler`
9. Fix `User.CreatedAt` compilation issue
10. Fix double `store.Close()` crash
11. Add `GET /my-images` endpoint for image retrieval

### Medium-Term (Next Quarter)
12. Add auth scoping to sync endpoints
13. Configure trusted proxies for rate limiter
14. Make Gosec fail the CI build on high-severity findings
15. Add audit log retry/fallback mechanism
16. Thread-safe camera access in Python app
17. Startup-only DB schema migrations (remove per-request `ensure_*` calls)

---

*This review was conducted on 2026-03-29 against the full OraScan codebase. Previous review: 2026-03-24.*
