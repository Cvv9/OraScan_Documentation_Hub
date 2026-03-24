# Orascan -- Comprehensive Code Review Report

**Date:** 2026-03-14
**Reviewed by:** Code Reviewer, Backend Developer, UI/UX Designer, IoT Engineer, DevOps Engineer
**Repos Reviewed:** OraScan_Automated_Scanning, OraScan_Manual_Scanning, OraScan_backend, OraScan-Facemesh

---

## Executive Summary

The Orascan project is an oral scanning platform with motorized camera control, comprising a Go backend, two Python desktop applications (automated and manual scanning), and a computer vision module. This review identified **67 findings** across security, code quality, backend, UI/UX, IoT/hardware, database, testing, and DevOps perspectives.

**The 3 most critical findings are all security-related:** production secrets committed to git, Aadhaar numbers stored in plaintext, and a trivially-guessable JWT secret. These must be addressed before any other work.

| Category | P0 | P1 | P2 | P3 | Total |
|----------|----|----|----|----|-------|
| Security | 3 | 3 | 3 | 1 | 10 |
| Code Quality | 0 | 2 | 5 | 2 | 9 |
| Backend | 0 | 3 | 3 | 1 | 7 |
| UI/UX | 0 | 2 | 5 | 2 | 9 |
| IoT/Hardware | 0 | 3 | 4 | 1 | 8 |
| Database | 0 | 2 | 2 | 1 | 5 |
| Testing | 0 | 2 | 0 | 0 | 2 |
| DevOps | 0 | 3 | 2 | 1 | 6 |
| Facemesh (CV) | 0 | 0 | 3 | 2 | 5 |
| Missing Features | 0 | 2 | 3 | 1 | 6 |
| **Total** | **3** | **22** | **30** | **12** | **67** |

---

## P0 -- CRITICAL (Fix Immediately)

### SEC-01: Production Secrets Committed to Git
- **File:** `OraScan_backend/.env` (lines 1-5)
- **Description:** The `.env` file contains plaintext production credentials: PostgreSQL password (`orsc#1234`), full Azure Storage Key (base64), and JWT secret. There is no `.gitignore` in any sub-repo. Anyone with repository access can read patient images from Azure Blob, connect to the production database, and forge JWT tokens.
- **Fix:** Rotate ALL credentials immediately. Add `.gitignore` to all repos. Scrub secrets from git history with BFG Repo-Cleaner. Use environment variables or a secrets manager.

### SEC-02: Weak JWT Secret -- Literal Placeholder String
- **File:** `OraScan_backend/.env:5`
- **Description:** The JWT secret is `super-secret-key-change-this-in-production` -- a trivially guessable placeholder. An attacker can forge Bearer tokens to call `/upload` to inject arbitrary files into Azure, or access any authenticated endpoint.
- **Fix:** Generate a cryptographically random 256-bit secret. Store in a secrets manager, never in source control.

### SEC-03: Aadhaar Numbers Stored in Plaintext
- **Files:** `OraScan_backend/storage.go:56`, `OraScan_Automated_Scanning/database_utils.py:39`, `OraScan_Automated_Scanning/register_page.py:32`
- **Description:** Aadhaar (India's national biometric ID, equivalent to SSN) is stored as plaintext in both MySQL (local) and PostgreSQL (cloud) with no encryption at rest. The registration form sends it as plain JSON. This violates the Aadhaar Act's data protection provisions.
- **Fix:** Encrypt Aadhaar at rest using AES-256. Only store the last 4 digits for display purposes. Implement field-level encryption in both MySQL and PostgreSQL.

---

## P1 -- HIGH (Fix Before Next Release)

### SEC-04: Plaintext Password Legacy Support
- **File:** `OraScan_Automated_Scanning/password_utils.py:24-25`
- **Description:** Legacy passwords are compared as plaintext strings. Users whose password was stored before the PBKDF2 migration still have plaintext passwords in the MySQL `patient` table. No forced migration or expiration exists.
- **Fix:** Force password reset for all legacy users. Add a migration script that flags plaintext passwords and requires change on next login.

### SEC-05: Password Hash Mismatch Between Desktop and Backend
- **Files:** `OraScan_Automated_Scanning/password_utils.py:9-16` (PBKDF2-SHA256, 120K iterations), `OraScan_backend/storage.go:73` (bcrypt)
- **Description:** Desktop app hashes with PBKDF2 and stores in MySQL. Go backend hashes with bcrypt in PostgreSQL. Users registered locally cannot authenticate via the backend, and vice versa. The two systems are fundamentally incompatible.
- **Fix:** Standardize on bcrypt across both systems. Add a migration path for existing PBKDF2 passwords.

### SEC-06: No CORS Configuration
- **File:** `OraScan_backend/api.go:39`
- **Description:** Gin router uses `gin.Default()` with no CORS middleware.
- **Fix:** Add `gin-contrib/cors` middleware with explicit allowed origins.

### CQ-01: Massive Code Duplication Between Automated and Manual Scanning
- **Files:** `api_client.py`, `password_utils.py`, `login_page.py`, `register_page.py`, `dashboard_page.py` -- 100% identical between repos
- **Description:** Bug fixes, security patches, or schema changes must be applied to both repos independently, creating divergence risk.
- **Fix:** Extract shared code into a common Python package (e.g., `orascan_common`) and install via relative path in both repos.

### CQ-02: Empty Critical Files in Manual Scanning
- **Files:** `OraScan_Manual_Scanning/main.py` (0 lines), `OraScan_Manual_Scanning/database_utils.py` (0 lines)
- **Description:** The manual scanning app has no entry point and no database utilities. It cannot start. `register_page.py` imports `database_utils` which will fail.
- **Fix:** Either populate these files or mark the Manual Scanning repo as deprecated/WIP.

### BE-01: Uploaded Images Not Linked to Users
- **File:** `OraScan_backend/api.go:49-121`
- **Description:** `UploadImageHandler` authenticates via JWT but never extracts user identity from token claims. Images upload to Azure Blob with random UUID filenames but no database record links them to patients. `SaveUserImage` in `storage.go` is entirely commented out (lines 97-124). Uploaded images are orphaned.
- **Fix:** Uncomment and fix `SaveUserImage`. Create the `patient_images` table. Extract user ID from JWT claims and record the image-to-patient mapping.

### BE-02: No `patient_images` Table Migration
- **File:** `OraScan_backend/storage.go:54-68`
- **Description:** Only `users` table is created. The `PatientImage` struct (type.go:31-38) references columns that don't exist. The commented-out `SaveUserImage` would fail.
- **Fix:** Add the `CREATE TABLE patient_images` statement to `Init()` or implement a proper migration framework.

### BE-03: No Rate Limiting on Authentication
- **File:** `OraScan_backend/api.go:41-42`
- **Description:** No rate limiter on `/login` or `/register`. Vulnerable to brute-force and registration flooding.
- **Fix:** Add rate limiting middleware (e.g., `ulule/limiter` for Gin).

### IOT-01: All Hardware Code Is Mocked in Automated Scanning
- **File:** `OraScan_Automated_Scanning/motor_driver.py`
- **Description:** Every hardware operation is a mock: `move_vertical_servo` just prints, `stepper_move_x/y` are `pass`, `StableServo.move_to_angle` only updates state. All `lgpio`, `HR8825`, `gpiozero` imports are commented out with no conditional fallback. The app cannot control any hardware.
- **Fix:** Add conditional imports with `try/except ImportError` to fall back to mocks when not on Pi. Implement actual hardware control for production.

### IOT-02: No Hardware Error Recovery
- **File:** `OraScan_Automated_Scanning/oral_photo_acquisition_page.py:60-70`
- **Description:** `perform_capture_step` runs via `run_in_executor` with no timeout. Contains `time.sleep(8)` not covered by the 5-second `hardware_timeout` decorator. If camera disconnects or motor stalls, the UI freezes indefinitely.
- **Fix:** Add a timeout wrapper around the entire executor call. Implement hardware health checks before starting a scan sequence.

### IOT-03: Camera Feed Loop Never Stops in Manual Scanning
- **File:** `OraScan_Manual_Scanning/oral_photo_acquisition_page.py:46-57`
- **Description:** Infinite `while True` loop with `asyncio.sleep(0.05)` as a `use_effect`. When user navigates away, the loop continues running, consuming CPU and holding the camera.
- **Fix:** Add a cancellation flag checked in the loop. Set flag in the effect cleanup callback.

### DB-01: Dual Database Architecture with No Sync
- **Description:** Desktop apps use MySQL locally (`pymysql`). Go backend uses PostgreSQL on Azure. No sync mechanism. Patient registered locally exists only in MySQL. Images uploaded via `/upload` go to Azure but are not in MySQL. Breath data, audio, and reports are MySQL-only. Schemas differ between the two databases.
- **Fix:** Design a sync protocol: either push from desktop to backend on connectivity, or switch to a single database with offline-capable access pattern.

### DB-02: No Database Migrations
- **Files:** `OraScan_backend/storage.go:54-68`, `OraScan_Automated_Scanning/database_utils.py:57-73`
- **Description:** Both use `CREATE TABLE IF NOT EXISTS` at runtime with no migration framework. The `ensure_h2s_column` does runtime `ALTER TABLE`. Schema changes cannot be versioned, tested, or rolled back.
- **Fix:** Adopt migration frameworks: `golang-migrate` for Go, Alembic for Python.

### DEV-01: No `.gitignore` in Any Repository
- **Description:** `.DS_Store`, `.env`, `__pycache__/`, `captured_images/` (patient photos), and `uploads/` are all potentially tracked.
- **Fix:** Add comprehensive `.gitignore` to all four repos immediately.

### DEV-02: No CI/CD Pipeline
- **Description:** No GitHub Actions, GitLab CI, or any automation. No builds, tests, linting, or deployment scripts.
- **Fix:** Add CI/CD with at minimum: lint, build, test steps for each repo.

### DEV-03: No Dockerfiles or Containerization
- **Description:** No container configuration for any sub-repo. Deployment is entirely manual.
- **Fix:** Create Dockerfiles for the backend and desktop apps. Add `docker-compose.yml` for local development.

### TEST-01: Zero Tests Across Entire Project
- **Description:** No test files, test directories, or test configurations in any of the four sub-repos. No `tests/` directory, no `*_test.py`, no `*_test.go`, no `pytest.ini`, no CI pipeline.
- **Fix:** Set up testing frameworks (pytest for Python, `go test` for Go). Start with critical paths: authentication, image upload, password hashing.

### TEST-02: Untestable Architecture
- **Description:** All page components are monolithic functions with inline database calls, API calls, and hardware control. No dependency injection. `motor_driver.py` uses module-level globals. `database_utils.py` directly calls `pymysql.connect`.
- **Fix:** Refactor to inject dependencies (database connections, API clients, hardware interfaces) as parameters. This enables testing with mocks.

---

## P2 -- MEDIUM (Address in Current Sprint)

### SEC-07: JWT Token Expires in 15 Minutes with No Refresh
- **File:** `OraScan_backend/api.go:183`
- **Description:** Token expires in 15 min. A full 13-step scan with 8-second delays takes 104+ seconds minimum, but pauses or breath/audio collection can push beyond 15 min. Upload will fail with 401.
- **Fix:** Implement refresh token flow. Or extend token expiry to match typical session duration (e.g., 2 hours).

### SEC-08: Patient Images on Azure Blob Have Public Container Access
- **File:** `OraScan_backend/api.go:116-118`
- **Description:** Container requires "Blob" public access. All patient oral images are publicly accessible by URL. Anyone who enumerates UUIDs can view medical images.
- **Fix:** Set container to private access. Generate SAS tokens for authorized downloads.

### SEC-09: No Rate Limiting -- Registration Flooding
- **Description:** `/register` endpoint has no rate limiting. Attacker can flood registrations.
- **Fix:** Add IP-based rate limiting.

### CQ-03: Global Mutable State for Camera
- **File:** `OraScan_Automated_Scanning/main.py:124`
- **Description:** `cap` (cv2.VideoCapture) is a module-level global. If two browser tabs connect, both share the same camera handle, causing race conditions on `cap.read()`.
- **Fix:** Create a camera manager class with proper locking.

### CQ-04: Global Mutable State for Motor/Servo
- **File:** `OraScan_Automated_Scanning/motor_driver.py:58-59`
- **Description:** Module-level globals with mutable `current_angle` state. No locking or synchronization.
- **Fix:** Wrap in a class with threading locks.

### CQ-05: `audio_data.py` Uses Tkinter Inside PyWebView App
- **File:** `OraScan_Automated_Scanning/audio_data.py:3-7`
- **Description:** Uses `tkinter.messagebox.showinfo` but the app runs inside PyWebView with ReactPy. Creates confusing second window or fails headless. `RecorderGUI` class (line 92) is dead code.
- **Fix:** Replace Tkinter calls with ReactPy UI elements. Remove dead `RecorderGUI`.

### CQ-06: `PyAudio` Instance Not Properly Managed
- **File:** `OraScan_Automated_Scanning/audio_data.py:74`
- **Description:** After `terminate()`, `save_audio_to_db` calls `self.audio.get_sample_size()` which fails. Second `start_recording()` also fails.
- **Fix:** Move `terminate()` to after `save_audio_to_db`. Add a `reset()` method for reuse.

### CQ-07: `camera_sequence_done` Global Flag -- One-Shot Only
- **File:** `OraScan_Automated_Scanning/oral_photo_acquisition.py:7`
- **Description:** Module-level flag prevents `servo_and_camera_sequence` from running more than once per process lifetime. Never reset.
- **Fix:** Remove the flag or provide a reset mechanism.

### BE-04: Azure Blob Client Recreated on Every Upload
- **File:** `OraScan_backend/api.go:49-74`
- **Description:** Every upload reads env vars, creates new credential, client, and container client. Adds latency and resource waste.
- **Fix:** Initialize Azure clients once at startup and store on `ApiServer`.

### BE-05: No Database Connection Pooling Configuration
- **File:** `OraScan_backend/storage.go:41`
- **Description:** No `SetMaxOpenConns`, `SetMaxIdleConns`, `SetConnMaxLifetime`. Pool grows unbounded under load.
- **Fix:** Configure pool settings after `sql.Open`.

### BE-06: Registration Returns 200 Instead of 201
- **File:** `OraScan_backend/api.go:135`
- **Fix:** Return `http.StatusCreated`.

### IOT-04: Breath Sensor Fully Simulated -- Stores Fake Data as Real
- **File:** `OraScan_Automated_Scanning/breath_sensor.py:18-24`
- **Description:** Returns `random.uniform(10, 150)`. No serial port communication despite `SERIAL_CONFIG` in config. Simulated readings stored in database as real medical data.
- **Fix:** Implement actual serial communication. Add a clear `SIMULATION_MODE` flag that tags data as simulated.

### IOT-05: Camera Frame Flushing Inefficient
- **File:** `OraScan_Manual_Scanning/oral_photo_acquisition_page.py:81`
- **Description:** Reads and discards 5 frames to flush buffer (~250ms latency).
- **Fix:** Set `cv2.CAP_PROP_BUFFERSIZE` to 1.

### IOT-06: No Graceful Hardware Cleanup on App Exit
- **File:** `OraScan_Automated_Scanning/main.py:127-137`
- **Description:** Camera released on shutdown but no servo/stepper cleanup. GPIO pins may stay in last state, overheating motors.
- **Fix:** Add GPIO cleanup to the `lifespan` shutdown handler.

### IOT-07: Manual Scanning Uses Deprecated `RPi.GPIO`
- **File:** `OraScan_Manual_Scanning/manual_hardware.py:6`
- **Description:** `RPi.GPIO` is deprecated. Automated Scanning uses `lgpio`. Inconsistent across repos.
- **Fix:** Standardize on `lgpio` or `gpiozero` across both repos.

### DB-03: No Indexes on Query Columns
- **Description:** MySQL `patient` table queried by `email` but no index. `reports` table queries by `patient_id` but no index.
- **Fix:** Add indices on `email` and `patient_id`.

### DB-04: Connection Per Query Pattern
- **File:** `OraScan_Automated_Scanning/database_utils.py:5-18`
- **Description:** Every function opens/closes a new MySQL connection. No connection pooling.
- **Fix:** Use a connection pool (e.g., `pymysql` with `DBUtils` or switch to SQLAlchemy).

### UX-01: No Cancel/Abort During Automated Scan
- **File:** `OraScan_Automated_Scanning/oral_photo_acquisition_page.py:41-89`
- **Description:** 13-step scan with 8-second delays (104+ seconds). No "Cancel" or "Pause" button. User must wait for full sequence or force-quit.
- **Fix:** Add an abort button that sets a cancellation flag checked between steps.

### UX-02: Scan Steps Not Retakeable
- **File:** `OraScan_Automated_Scanning/oral_photo_acquisition_page.py:52-86`
- **Description:** Poor quality image at step 5 requires completing all 13 steps, then restarting from scratch.
- **Fix:** Add a "Retake" button per step. Show the captured image for each step with accept/reject option.

### UX-03: Forgot Password Page Lies About Sending Email
- **File:** `OraScan_Automated_Scanning/forgot_password_page.py:14-18`
- **Description:** Displays "Password reset link sent to {email}" but no email is actually sent.
- **Fix:** Either implement email sending or change the UI to say "Contact your administrator."

### UX-04: View Past Reports Inserts Dummy Data
- **File:** `OraScan_Automated_Scanning/view_past_reports_page.py:14-16`
- **Description:** If no reports exist, inserts a fake "Routine Checkup" report dated 2024-01-28 into the database. Contaminates real patient data with fabricated medical records.
- **Fix:** Remove the dummy data insertion. Show "No reports yet" instead.

### UX-05: "Email to Me" Button Does Nothing
- **File:** `OraScan_Automated_Scanning/view_past_reports_page.py:21-27`
- **Description:** Only `print()`s to console. Tells user the email was sent when it was not.
- **Fix:** Either implement email or remove the button. Never display success for a non-existent action.

### UX-06: Settings Page Entirely Non-Functional
- **File:** `OraScan_Automated_Scanning/settings_page.py:17-31`
- **Description:** Shows three static text items (Notifications, Privacy, Account). Nothing is clickable or functional.
- **Fix:** Either implement settings or add "Coming Soon" labels.

### UX-07: Scan History Never Queries Database
- **File:** `OraScan_Automated_Scanning/scan_history_page.py:27`
- **Description:** Always shows static "No recent scans found" regardless of actual data.
- **Fix:** Query the database for actual scan history.

### DEV-04: Unpinned Python Dependencies
- **File:** `OraScan_Manual_Scanning/requirements.txt`
- **Description:** All dependencies unpinned. No `requirements.txt` at all for OraScan_Automated_Scanning.
- **Fix:** Pin all dependencies. Create `requirements.txt` for Automated Scanning. Use `pip-compile` for reproducible builds.

### DEV-05: No Logging Framework
- **Description:** All repos use bare `print()` statements. No structured logging, log levels, or log rotation. In a clinical device, audit logging is critical.
- **Fix:** Adopt Python `logging` module with structured JSON output. Add Go's `log/slog` or `zap` for the backend.

### CV-01: Facemesh Scripts Not Importable
- **Files:** `OraScan-Facemesh/mouth.py`, `smile.py`, `tongue.py`
- **Description:** All execute code at module level (camera open, infinite loops). Cannot be imported without immediately starting processing.
- **Fix:** Wrap in classes/functions with `if __name__ == "__main__"` guards.

### CV-02: Hardcoded Resolution-Dependent Thresholds
- **Files:** `mouth.py:32` (`> 45`), `smile.py:42` (`> 100`), `tongue.py:49` (`< 50`)
- **Description:** Pixel thresholds break with different camera resolutions.
- **Fix:** Normalize relative to face size (e.g., as percentage of inter-eye distance).

### CV-03: Variable Shadowing in tongue.py
- **File:** `OraScan-Facemesh/tongue.py:46`
- **Description:** `h, w` from `frame.shape` overwritten by `cv2.boundingRect`. Breaks subsequent iterations.
- **Fix:** Use different variable names for bounding rect dimensions.

### FEAT-01: No Data Synchronization Pipeline
- **Description:** Local MySQL data never reaches the cloud backend. `api_client.py` `upload_images()` only uploads images, not metadata, breath data, or audio. No background sync worker.
- **Fix:** Design a sync protocol with offline queue, conflict resolution, and progress tracking.

### FEAT-02: No Facemesh Integration
- **Description:** Facemesh scripts are standalone demos, not integrated into desktop apps. Real-time guidance ("open mouth wider") would reduce unusable captures.
- **Fix:** Refactor Facemesh into importable modules. Integrate as real-time overlays during scanning.

### FEAT-03: No Image Quality Validation
- **Description:** No blur detection, brightness check, or content verification before upload. Poor-quality images provide no diagnostic value.
- **Fix:** Add OpenCV-based quality checks (Laplacian variance for blur, histogram analysis for brightness).

---

## P3 -- LOW (Backlog)

### CQ-08: Inconsistent Naming Across Systems
- **Description:** `f_name`/`l_name`/`Aadhar` (Python/MySQL) vs `first_name`/`last_name`/`aadhar` (Go/PostgreSQL). Creates mapping bugs.
- **Fix:** Standardize naming conventions across all systems.

### CQ-09: Hardcoded Magic Numbers
- **Files:** `oral_photo_acquisition.py:31` (`sleep(8)`), `mouth.py:32` (`> 45`), `api.go:82` (`10*1024*1024`)
- **Fix:** Extract to named constants.

### BE-07: Error Leaks Internal Details
- **File:** `OraScan_backend/api.go:131`
- **Description:** PostgreSQL error messages returned to client.
- **Fix:** Log internal error, return generic message.

### UX-08: Inline JavaScript Event Handlers in ReactPy
- **Description:** Raw JS strings as `onmouseover` handlers throughout. Bypasses ReactPy's event model.
- **Fix:** Use ReactPy event handlers instead of inline JS.

### UX-09: No Loading Indicators
- **Description:** No loading spinners or progress bars during database queries, API calls, or uploads.
- **Fix:** Add visual progress feedback for all async operations.

### IOT-08: Stepper Direction Logic Has Unresolved Dev Notes
- **File:** `OraScan_Manual_Scanning/manual_hardware.py:109-123`
- **Fix:** Resolve direction mapping, remove debug comments.

### CV-04: No Error Handling for Camera Initialization
- **File:** `OraScan-Facemesh/mouth.py:10`
- **Fix:** Check `cap.isOpened()` and show clear error message.

### CV-05: Inconsistent Exit Keys
- **Description:** `mouth.py` and `smile.py` use Esc, `tongue.py` uses `q`.
- **Fix:** Standardize on one exit key.

### DB-05: Audio BLOBs in MySQL
- **File:** `OraScan_Automated_Scanning/audio_data.py:40`
- **Description:** 1.7MB audio files stored as BLOBs. Bloats database, slows backups.
- **Fix:** Store on disk or object storage with DB reference.

### DEV-06: Non-Code Artifacts in Repos
- **File:** `OraScan_backend/WhatsApp Image 2025-08-12 at 17.53.31.jpeg`
- **Fix:** Remove and add to `.gitignore`.

### FEAT-04: No Patient Data Export
- **Description:** No PDF, CSV, or portable format export. "Email to Me" is non-functional.
- **Fix:** Add export functionality using ReportLab (PDF) or csv module.

### FEAT-05: No Scan Session Management
- **Description:** No session ID or timestamp correlation. Multiple scans overwrite files (same filenames like `Smile_showing_front_teeth.jpg`).
- **Fix:** Add a session model with UUID, timestamp, and file organization.

### FEAT-06: No Offline Upload Queue
- **Description:** When backend is unavailable, images remain only on disk. No retry queue or pending upload manifest.
- **Fix:** Implement a local queue with retry logic and exponential backoff.

---

## Recommended Action Plan

### Sprint 0 (Immediate -- Security Emergency)
1. Rotate ALL credentials in `.env` (PostgreSQL, Azure Storage, JWT secret)
2. Add `.gitignore` to all 4 repos
3. Scrub secrets from git history with BFG Repo-Cleaner
4. Encrypt or remove Aadhaar storage
5. Generate cryptographically strong JWT secret (256-bit)
6. Make Azure Blob container private, use SAS tokens

### Sprint 1 (P1 -- Security & Architecture)
1. Fix password hash mismatch (standardize on bcrypt)
2. Add CORS middleware and rate limiting
3. Extract shared code into `orascan_common` package
4. Fix empty Manual Scanning files or deprecate the repo
5. Link uploaded images to patients in database
6. Create `patient_images` table with proper migration

### Sprint 2 (P1 -- Quality & Infrastructure)
1. Add CI/CD pipeline (lint, build, test)
2. Create test framework with initial tests for auth, upload, and password hashing
3. Add structured logging throughout
4. Add Dockerfiles for backend and desktop apps

### Sprint 3 (P2 -- Features & UX)
1. Add scan abort/retry functionality
2. Refactor Facemesh for importability, integrate into scanning
3. Implement offline upload queue
4. Fix all non-functional UI elements (settings, scan history, forgot password, email)
5. Add image quality validation before upload
6. Remove fake data insertion in past reports
