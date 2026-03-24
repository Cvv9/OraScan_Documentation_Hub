# Orascan Project — Full Route, Endpoint, Component & Schema Extraction

**Extracted:** 2026-03-22
**Sub-repos found:** `OraScan_Automated_Scanning`, `OraScan_Manual_Scanning`, `OraScan_backend`, `OraScan-Facemesh`, `orascan_common`

---

## Automated Scanning App Routes/Screens

The app is a **FastAPI + ReactPy + PyWebView** desktop application. ReactPy components render server-side and are served inside a PyWebView native window. Routing is handled via `use_state("/login")` in the root `App` component — there is no client-side router; navigation is driven by `set_current_path()`.

**Entry point:** `main.py` — starts FastAPI via Uvicorn on a background thread, then opens `webview.create_window("OraScan", ...)` pointing at `http://localhost:{port}`.

**Static file mounts:**
- `/images` → `images/UI/`
- `/captured_images` → `{cwd}/captured_images/`
- `/oral_images_samples` → `images/Dental_Images/`
- `/Combined` → `images/Dental_Gifs/`

#### Login Page
- **URL:** `/login`
- **Component:** `login_page.py` (`LoginPage`)
- **Access:** Public
- **Backend API:** `POST /login` → `api.go` (via `api_client.py`)
- **Database tables:** `patient` (local MySQL — email lookup via `database_utils.py`)
- **Known issues:** _none_
- **Last audited:** _never_

#### Register Page
- **URL:** `/register`
- **Component:** `register_page.py` (`RegisterPage`)
- **Access:** Public
- **Backend API:** `POST /register` → `api.go` (via `api_client.py`)
- **Database tables:** `patient` (local MySQL), `users` (backend PostgreSQL)
- **Known issues:** _none_
- **Last audited:** _never_

#### Forgot Password Page
- **URL:** `/forgot-password`
- **Component:** `forgot_password_page.py` (`ForgotPasswordPage`)
- **Access:** Public
- **Backend API:** _none_ (operates on local MySQL only)
- **Database tables:** `patient` (local MySQL — `fetch_user_details`, `update_user_password`)
- **Known issues:** _none_
- **Last audited:** _never_

#### Dashboard Page
- **URL:** `/dashboard`
- **Component:** `dashboard_page.py` (`DashboardPage`)
- **Access:** Authenticated (redirects to `/login` if no user)
- **Backend API:** _none directly_
- **Database tables:** _none directly_
- **Known issues:** _none_
- **Last audited:** _never_

#### Oral Photo Acquisition Page
- **URL:** `/oral-photo-acquisition`
- **Component:** `oral_photo_acquisition_page.py` (`OralPhotoAcquisitionPage`)
- **Access:** Authenticated
- **Backend API:** `POST /upload` → `api.go` (via `api_client.py` `upload_images()`)
- **Database tables:** `patient_images` (backend PostgreSQL)
- **Known issues:** _none_
- **Last audited:** _never_

#### Profile Page
- **URL:** `/profile`
- **Component:** `profile_page.py` (`ProfilePage`)
- **Access:** Authenticated
- **Backend API:** _none_ (reads/writes local MySQL)
- **Database tables:** `patient` (local MySQL — `update_user_details`)
- **Known issues:** _none_
- **Last audited:** _never_

#### Scan History Page
- **URL:** `/scan-history`
- **Component:** `scan_history_page.py` (`ScanHistoryPage`)
- **Access:** Authenticated
- **Backend API:** _unknown_
- **Database tables:** _unknown_
- **Known issues:** _none_
- **Last audited:** _never_

#### Settings Page
- **URL:** `/settings`
- **Component:** `settings_page.py` (`SettingsPage`)
- **Access:** Public (no auth guard in routing)
- **Backend API:** _none_
- **Database tables:** _none_
- **Known issues:** No auth guard — accessible without login
- **Last audited:** _never_

#### Audio Data Page
- **URL:** `/audio-data`
- **Component:** `audio_data_page.py` (`AudioDataPage`)
- **Access:** Authenticated
- **Backend API:** _none_
- **Database tables:** _unknown_
- **Known issues:** _none_
- **Last audited:** _never_

#### Breath Data Page
- **URL:** `/breath-data`
- **Component:** `breath_data_page.py` (`BreathDataPage`)
- **Access:** Authenticated
- **Backend API:** _none_
- **Database tables:** _unknown_ (may use `h2s_value` column in `patient`)
- **Known issues:** _none_
- **Last audited:** _never_

#### Questionnaire Page
- **URL:** `/questionnaire`
- **Component:** `questionnaire_page.py` (`QuestionnairePage`)
- **Access:** Authenticated
- **Backend API:** _unknown_
- **Database tables:** _unknown_
- **Known issues:** _none_
- **Last audited:** _never_

#### Oral Health Tips Page
- **URL:** `/oral-health-tips`
- **Component:** `oral_health_tips_page.py` (`OralHealthTipsPage`)
- **Access:** Authenticated
- **Backend API:** _none_ (static content / placeholder)
- **Database tables:** _none_
- **Known issues:** Page content is placeholder
- **Last audited:** _never_

#### View Past Reports Page
- **URL:** `/view-past-reports`
- **Component:** `view_past_reports_page.py` (`ViewPastReportsPage`)
- **Access:** Authenticated
- **Backend API:** _unknown_
- **Database tables:** _unknown_
- **Known issues:** _none_
- **Last audited:** _never_

### Additional Files (not routable screens)
- `api_client.py` — HTTP client wrapper for Go backend (`BACKEND_URL` default `http://127.0.0.1:3000`)
- `database_utils.py` — Local MySQL CRUD for `patient` table
- `config.py` — `DB_CONFIG` dict for local MySQL connection
- `password_utils.py` — bcrypt hashing/verification
- `audio_data.py` — Tkinter-based audio recording window (1300x700), separate from ReactPy
- `motor_driver.py` — Hardware motor control (RPi GPIO)
- `hardware_config.py` — Hardware pin configuration
- `breath_sensor.py` — H2S breath sensor interface

---

## Backend API Endpoints

**Stack:** Go (Gin framework), PostgreSQL, Azure Blob Storage
**Default port:** 3000
**Source:** `OraScan_backend/`

#### Register User
- **URL:** `POST /register`
- **Component:** `api.go` → `RegisterHandler`
- **Access:** Public (rate-limited via `RateLimitMiddleware`)
- **Backend API:** `POST /register` → `api.go`
- **Database tables:** `users`
- **Known issues:** _none_
- **Last audited:** _never_

#### Login User
- **URL:** `POST /login`
- **Component:** `api.go` → `LoginHandler`
- **Access:** Public (rate-limited via `RateLimitMiddleware`)
- **Backend API:** `POST /login` → `api.go`
- **Database tables:** `users`
- **Known issues:** _none_
- **Last audited:** _never_

#### Upload Image
- **URL:** `POST /upload`
- **Component:** `api.go` → `UploadImageHandler`
- **Access:** Authenticated (JWT via `authMiddleware`)
- **Backend API:** `POST /upload` → `api.go`
- **Database tables:** `patient_images`
- **Known issues:** _none_
- **Last audited:** _never_

### Authentication Model

- **Type:** JWT (HS256), using `golang-jwt/v5`
- **Secret:** `JWT_SECRET` env var (minimum 32 chars enforced)
- **Middleware:** `authMiddleware()` in `api.go` — extracts `Authorization: Bearer <token>` header, parses JWT, sets `userID` in Gin context
- **Rate limiting:** `RateLimitMiddleware` applied to `/register` and `/login` (defined in `middleware.go`)
- **CORS:** Configured via `CORSMiddleware` with `ALLOWED_ORIGINS` env var
- **Password hashing:** bcrypt via `golang.org/x/crypto/bcrypt`
- **Aadhaar encryption:** AES-256-GCM (`crypto.go`) with `ENCRYPTION_KEY` env var

### Azure Blob Storage Integration

- **Config:** `AZURE_STORAGE_ACCOUNT`, `AZURE_STORAGE_KEY`, `AZURE_CONTAINER_NAME` env vars (`config.go`)
- **Client init:** `service.NewClientWithSharedKeyCredential` at server startup (`api.go`)
- **Upload flow:** `UploadImageHandler` receives multipart file → uploads to Azure Blob → stores blob URL in `patient_images` table
- **Access model:** Private blobs with SAS token generation for read access
- **SAS URL format:** `https://{account}.blob.core.windows.net/{container}/{blobName}?{sasToken}` (time-limited)

### Database Schema (PostgreSQL — Backend)

**Connection:** `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` env vars
**Pool:** 25 max open, 5 max idle, 5min lifetime (configured in `storage.go`)

#### Table: `users`
```sql
CREATE TABLE IF NOT EXISTS users (
    id              SERIAL PRIMARY KEY,
    first_name      TEXT,
    last_name       TEXT,
    contact         TEXT,
    email           TEXT UNIQUE NOT NULL,
    place           TEXT,
    aadhar          TEXT,               -- DEPRECATED: backward compat only
    aadhar_encrypted TEXT,              -- AES-256-GCM encrypted Aadhaar
    aadhar_last4    TEXT,               -- Last 4 digits for display
    password        TEXT NOT NULL,
    image_path      TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### Table: `patient_images`
```sql
CREATE TABLE IF NOT EXISTS patient_images (
    id              SERIAL PRIMARY KEY,
    patient_id      INTEGER REFERENCES users(id),
    image_url       TEXT NOT NULL,       -- Azure Blob URL
    image_identifier TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Go Structs (Models)

| Struct | File | Purpose |
|--------|------|---------|
| `RegisterInput` | `type.go` | Registration payload (first_name, last_name, email, password, contact, place, aadhar) |
| `LoginInput` | `type.go` | Login payload (email, password) |
| `User` | `type.go` | DB model for `users` table |
| `PatientImage` | `type.go` | DB model for `patient_images` table (includes `image_url`) |
| `Config` | `config.go` | App config (DB, JWT, Azure, GinMode, ListenAddr, AllowedOrigins, EncryptionKey) |
| `ApiServer` | `api.go` | Server struct (store, cfg, azureClient, azureCred, rateLimiter) |
| `PostgresStore` | `storage.go` | Database access layer implementing `Storage` interface |
| `RateLimiter` | `middleware.go` | Token-bucket rate limiter |

### Storage Interface
```go
type Storage interface {
    Init() error
    CreateUser(*RegisterInput, *Config) error
    GetUserByEmail(email string) (*User, error)
    SaveUserImage(userID int, blobURL string, identifier string) (*PatientImage, error)
    GetUserByID(id int) (*User, error)
    Close()
}
```

### Migration Scripts
- `migrations/encrypt_aadhaar.go` — One-time migration to encrypt existing plaintext Aadhaar values with AES-256-GCM, stores encrypted value + last 4 digits

### Database Schema (MySQL — Local Desktop App)

**Connection:** Configured in `config.py` via `DB_CONFIG` dict (pymysql)

#### Table: `patient`
Columns (inferred from `database_utils.py` queries):
- `id` — Primary key
- `f_name` — First name
- `l_name` — Last name
- `email` — Email (used for lookups)
- `password` — Hashed password
- `contact` — Phone number
- `Aadhar` — Aadhaar number
- `place` — Location (inferred from registration)
- `h2s_value` — H2S breath reading (added via `ensure_h2s_column`)

### WebSocket / Real-time Communication
- **None found.** No WebSocket endpoints exist in the backend or desktop app.

---

## Facemesh Module Entry Points

**Stack:** Python, OpenCV, MediaPipe FaceMesh
**Location:** `OraScan-Facemesh/`
**Type:** Standalone CV demos (no API endpoints, no integration with backend)

#### Mouth Detection
- **URL:** _N/A (standalone script)_
- **Component:** `mouth.py`
- **Access:** _N/A_
- **Backend API:** _none_
- **Database tables:** _none_
- **Known issues:** _none_
- **Last audited:** _never_

**Description:** Opens webcam via `cv2.VideoCapture(0)`, uses MediaPipe FaceMesh to detect mouth landmarks (upper lip #11, lower lip #17, corners #61/#291). Measures mouth opening distance, applies threshold-based smile detection, displays annotated video feed. Press `q` to quit.

#### Tongue Detection
- **URL:** _N/A (standalone script)_
- **Component:** `tongue.py`
- **Access:** _N/A_
- **Backend API:** _none_
- **Database tables:** _none_
- **Known issues:** _none_
- **Last audited:** _never_

**Description:** Opens webcam, uses MediaPipe FaceMesh to detect lower lip position, applies HSV color masking to detect tongue (red/pink region below lower lip), draws bounding rectangle when tongue is detected. Press `q` to quit.

#### Smile Detection
- **URL:** _N/A (standalone script)_
- **Component:** `smile.py`
- **Access:** _N/A_
- **Backend API:** _none_
- **Database tables:** _none_
- **Known issues:** _none_
- **Last audited:** _never_

**Description:** Opens webcam, uses MediaPipe FaceMesh to extract mouth ROI, converts to grayscale and applies binary threshold. Classifies as "Great Smile" when mouth opening > 2px and white pixel count > 100. Press `q` to quit.

---

## Additional Sub-Repos

### OraScan_Manual_Scanning
A parallel desktop app with the same page structure as Automated Scanning but designed for manual (non-motorized) camera control. Contains equivalent files:
- `main.py`, `login_page.py`, `register_page.py`, `dashboard_page.py`, `profile_page.py`, `questionnaire_page.py`, `oral_photo_acquisition_page.py`, `scan_history_page.py`, `forgot_password_page.py`, `breath_data_page.py`, `audio_data_page.py`, `oral_health_tips_page.py`, `settings_page.py`, `view_past_reports_page.py`
- `manual_hardware.py` — RPi GPIO control (with graceful fallback on non-Pi environments)
- `hardware_config.py` — Pin configuration
- `api_client.py`, `database_utils.py`, `config.py`, `password_utils.py`
- Same routing model via ReactPy `set_current_path()`

### orascan_common
Shared Python package (`orascan_common/`) containing:
- `password_utils.py` — Shared password hashing utilities

---

## Summary Statistics

| Category | Count |
|----------|-------|
| Desktop app screens (Automated) | 13 |
| Desktop app screens (Manual) | 13 (mirror) |
| Backend API endpoints | 3 |
| PostgreSQL tables | 2 (`users`, `patient_images`) |
| Local MySQL tables | 1 (`patient`) |
| Facemesh standalone scripts | 3 |
| Sub-repos | 5 |
| WebSocket endpoints | 0 |
| Azure Blob integration points | 1 (upload + SAS read) |
