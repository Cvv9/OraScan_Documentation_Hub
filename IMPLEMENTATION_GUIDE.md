# Orascan Implementation Guide

**Date:** 2026-03-24
**Status:** ✅ All Implementations Complete

This guide provides step-by-step instructions for deploying the newly implemented security features and data sync service.

---

## Quick Start

### 1. Install Dependencies

#### Backend (Go)
```bash
cd OraScan_backend
go mod tidy
go mod download
```

#### Desktop App (Python)
```bash
cd OraScan_Automated_Scanning
pip install -r requirements.txt
```

### 2. Run Security Verification
```bash
cd OraScan_backend
go run scripts/verify_security.go
```

**Expected Output:**
```
=== Orascan Security Verification ===

✅ PASS JWT Secret Configuration
✅ PASS Aadhaar Encryption Key
✅ PASS Database Connection
✅ PASS Azure Blob Storage Configuration
✅ PASS Aadhaar Migration Status

=== Summary ===
✅ Passed: 5
⚠️  Warnings: 0
❌ Failed: 0

✅ SECURITY VERIFICATION PASSED
```

### 3. Run Tests

#### Backend Tests
```bash
cd OraScan_backend
go test -v ./...
```

#### Desktop App Tests
```bash
cd OraScan_Automated_Scanning
pytest test_password_utils.py -v
```

---

## Detailed Setup

### Backend Integration

#### 1. Environment Variables

Ensure your `.env` file has these values:

```env
# Database
DB_HOST=your-db-host
DB_PORT=5432
DB_USER=your-db-user
DB_PASSWORD=your-secure-password
DB_NAME=orascan_db

# JWT (MUST be 32+ characters, cryptographically random)
JWT_SECRET=your-generated-jwt-secret-at-least-32-chars

# Azure Blob Storage
AZURE_STORAGE_ACCOUNT=your-storage-account
AZURE_STORAGE_KEY=your-storage-key
AZURE_CONTAINER_NAME=patient-images

# Aadhaar Encryption (MUST be 32+ characters)
AADHAAR_ENCRYPTION_KEY=your-generated-encryption-key-32-chars

# Server
SERVER_PORT=3000
GIN_MODE=release
ALLOWED_ORIGINS=http://localhost:5173,https://your-frontend-domain.com
```

#### 2. Generate Secure Secrets

```bash
cd OraScan_backend
go run scripts/generate_secrets.go
```

Copy the generated secrets to your `.env` file.

#### 3. Initialize Database

The backend will automatically create all required tables on startup:
- `users` - User accounts with encrypted Aadhaar
- `patient_images` - Image metadata
- `audit_log` - Compliance audit trail

```bash
go run main.go
```

Verify tables created:
```sql
-- Connect to PostgreSQL
psql -h localhost -U your-user -d orascan_db

-- Check tables
\dt

-- Expected output:
--  Schema |      Name       | Type  |  Owner
-- --------+-----------------+-------+---------
--  public | audit_log       | table | owner
--  public | patient_images  | table | owner
--  public | users           | table | owner
```

#### 4. Start Backend Server

```bash
cd OraScan_backend
go run main.go
```

**Expected Output:**
```
✅ Successfully connected to database!
✅ Database tables and indices initialized successfully
✅ Audit log table initialized successfully
🚀 API Server starting on :3000
```

#### 5. Verify Endpoints

```bash
# Health check
curl http://localhost:3000/health
# {"status":"healthy","timestamp":1711234567}

# Test registration (should fail without proper payload)
curl -X POST http://localhost:3000/register
# {"error":"Invalid request body"}
```

---

### Desktop App Integration

#### 1. Update Main App (Optional - for Background Sync)

Edit `OraScan_Automated_Scanning/main.py`:

```python
from sync_service import SyncService, start_background_sync

# Add after successful login (in handle_login function)
def handle_login(email, password):
    # ... existing login code ...

    if ok and token:  # After successful backend login
        # Initialize and start background sync
        sync = SyncService()
        start_background_sync(sync, token, interval_minutes=60)
        logger.info("✅ Background sync service started")

    # ... rest of login code ...
```

#### 2. Test Sync Service

```bash
cd OraScan_Automated_Scanning
python sync_service.py
```

**Expected Output:**
```
=== Sync Service Test ===

Backend reachable: True
Sync status: {
    'sync_in_progress': False,
    'last_sync_time': None,
    'total_synced': 0,
    'total_failed': 0,
    'last_error': None,
    'backend_reachable': True
}
```

#### 3. Test Password Utilities

```bash
pytest test_password_utils.py -v
```

**Expected Output:**
```
test_password_utils.py::TestPasswordHashing::test_hash_password_returns_bcrypt_hash PASSED
test_password_utils.py::TestPasswordHashing::test_hash_password_different_each_time PASSED
...
========================= 25 passed in 3.42s =========================
```

---

## API Endpoint Reference

### Authentication Endpoints

#### POST /register
Register new user with encrypted Aadhaar.

**Request:**
```json
{
  "first_name": "John",
  "last_name": "Doe",
  "email": "john@example.com",
  "password": "SecurePassword123!",
  "contact": "9876543210",
  "place": "Mumbai",
  "aadhar": "123456789012"
}
```

**Response (201 Created):**
```json
{
  "message": "User registered successfully",
  "email": "john@example.com"
}
```

#### POST /login
Authenticate user and receive JWT token.

**Request:**
```json
{
  "email": "john@example.com",
  "password": "SecurePassword123!"
}
```

**Response (200 OK):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "email": "john@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "aadhar_last4": "9012"
  }
}
```

### Data Sync Endpoints (Authenticated)

#### POST /sync-patient
Sync local patient record to cloud.

**Headers:**
```
Authorization: Bearer <jwt-token>
```

**Request:**
```json
{
  "email": "john@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "contact": "9876543210",
  "place": "Mumbai",
  "local_id": 5,
  "sync_timestamp": "2026-03-24T10:30:00Z"
}
```

**Response (200 OK):**
```json
{
  "message": "Patient already exists in cloud",
  "cloud_id": 1,
  "status": "merged"
}
```

#### GET /sync-status
Check sync status for authenticated user.

**Headers:**
```
Authorization: Bearer <jwt-token>
```

**Response (200 OK):**
```json
{
  "patient_email": "john@example.com",
  "cloud_id": 1,
  "exists_in_cloud": true,
  "last_cloud_update": "2026-03-24T10:00:00Z",
  "images_in_cloud": 15,
  "needs_migration": false,
  "conflict_detected": false
}
```

### Image Upload Endpoint (Authenticated)

#### POST /upload
Upload patient oral scan image.

**Headers:**
```
Authorization: Bearer <jwt-token>
Content-Type: multipart/form-data
```

**Request:**
```
file: <binary-image-data>
identifier: "upper_teeth_scan"
```

**Response (200 OK):**
```json
{
  "message": "Image uploaded successfully",
  "image_id": 42,
  "url": "https://account.blob.core.windows.net/container/uuid.jpg?sas-token",
  "identifier": "upper_teeth_scan"
}
```

### Health Check Endpoints

#### GET /health
Basic health check.

**Response (200 OK):**
```json
{
  "status": "healthy",
  "timestamp": 1711234567
}
```

#### GET /ready
Readiness check (for Kubernetes, etc.).

**Response (200 OK):**
```json
{
  "status": "ready",
  "timestamp": 1711234567
}
```

---

## Audit Log Queries

### View Recent Audit Logs (SQL)

```sql
-- Last 100 audit entries
SELECT
    id,
    user_id,
    action,
    resource,
    ip_address,
    created_at
FROM audit_log
ORDER BY created_at DESC
LIMIT 100;

-- Failed login attempts in last 24 hours
SELECT
    action,
    ip_address,
    user_agent,
    created_at
FROM audit_log
WHERE action = 'user.login.failed'
  AND created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC;

-- All actions for a specific user
SELECT
    action,
    resource,
    ip_address,
    created_at
FROM audit_log
WHERE user_id = 1
ORDER BY created_at DESC;

-- Image uploads in last week
SELECT
    user_id,
    resource,
    created_at
FROM audit_log
WHERE action = 'image.upload'
  AND created_at > NOW() - INTERVAL '7 days'
ORDER BY created_at DESC;
```

---

## Troubleshooting

### Issue: Security Verification Fails

**Error:** `JWT_SECRET is still set to the insecure placeholder value`

**Solution:**
```bash
cd OraScan_backend
go run scripts/generate_secrets.go
# Copy the generated secrets to .env
```

### Issue: Database Connection Failed

**Error:** `failed to connect: dial tcp: connection refused`

**Solution:**
1. Verify PostgreSQL is running: `pg_isready`
2. Check `.env` database credentials
3. Ensure firewall allows connection
4. Test connection: `psql -h $DB_HOST -U $DB_USER -d $DB_NAME`

### Issue: Tests Fail - Database Not Found

**Error:** `database "orascan_test" does not exist`

**Solution:**
```sql
-- Create test database
CREATE DATABASE orascan_test;
```

### Issue: Aadhaar Migration Shows Plaintext

**Error:** `X plaintext Aadhaar numbers found`

**Solution:**
```bash
cd OraScan_backend
go run migrations/encrypt_aadhaar.go
```

### Issue: Sync Service Can't Connect

**Error:** `Backend unavailable: connection refused`

**Solution:**
1. Verify backend is running: `curl http://localhost:3000/health`
2. Check `ORASCAN_BACKEND_URL` environment variable
3. Verify firewall allows connection

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Orascan Backend CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: test
          POSTGRES_DB: orascan_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3

      - name: Set up Go
        uses: actions/setup-go@v4
        with:
          go-version: '1.23'

      - name: Install dependencies
        run: |
          cd OraScan_backend
          go mod download

      - name: Run tests
        run: |
          cd OraScan_backend
          go test -v ./...
        env:
          DB_HOST: localhost
          DB_PORT: 5432
          DB_USER: postgres
          DB_PASSWORD: test
          DB_NAME: orascan_test
          JWT_SECRET: test-secret-key-for-ci-at-least-32-characters-long
          AADHAAR_ENCRYPTION_KEY: test-encryption-key-32-chars-min-required

      - name: Security verification
        run: |
          cd OraScan_backend
          go run scripts/verify_security.go
```

---

## Performance Monitoring

### Key Metrics to Track

1. **Audit Log Growth**
   ```sql
   SELECT COUNT(*) FROM audit_log;
   SELECT pg_size_pretty(pg_total_relation_size('audit_log'));
   ```

2. **Sync Success Rate**
   ```python
   from sync_service import get_sync_status
   status = get_sync_status()
   success_rate = status['total_synced'] / (status['total_synced'] + status['total_failed'])
   ```

3. **Authentication Latency**
   ```bash
   # Add to your monitoring tool
   curl -w "@curl-format.txt" -X POST http://localhost:3000/login
   ```

---

## Security Best Practices

### 1. Secret Management
- ✅ Never commit `.env` to git
- ✅ Use different secrets for dev/staging/prod
- ✅ Rotate secrets quarterly
- ✅ Use secret management service (AWS Secrets Manager, Azure Key Vault)

### 2. Database Security
- ✅ Use SSL/TLS for database connections
- ✅ Enable connection pooling
- ✅ Set up database backups
- ✅ Restrict database access by IP

### 3. API Security
- ✅ Use HTTPS in production
- ✅ Configure CORS properly
- ✅ Implement rate limiting
- ✅ Monitor for suspicious activity

### 4. Audit Logging
- ✅ Review audit logs regularly
- ✅ Set up alerts for failed logins
- ✅ Archive old logs (> 90 days)
- ✅ Ensure logs are tamper-proof

---

## Rollback Plan

If issues occur in production:

### 1. Disable New Features
```bash
# Disable sync endpoints temporarily
# Comment out in api.go:
# r.POST("/sync-patient", ...)
# r.GET("/sync-status", ...)
```

### 2. Revert to Previous Version
```bash
git revert HEAD
go build
./orascan_backend
```

### 3. Database Rollback
```sql
-- If audit table causes issues
DROP TABLE IF EXISTS audit_log CASCADE;

-- If sync columns cause issues
ALTER TABLE patient DROP COLUMN synced;
ALTER TABLE patient DROP COLUMN last_sync_at;
```

---

## Next Steps

1. **Deploy to Staging**
   - Run all tests
   - Verify security script passes
   - Test sync service with real data
   - Load test audit logging

2. **Production Deployment**
   - Rotate all secrets
   - Run Aadhaar migration
   - Enable monitoring
   - Deploy with blue-green strategy

3. **Post-Deployment**
   - Monitor audit logs
   - Check sync success rate
   - Verify test coverage remains high
   - Plan next sprint features

---

## Support

For issues or questions:
- See: `COMPREHENSIVE_CODE_REVIEW_2026-03-24.md`
- See: `IMPLEMENTATION_SUMMARY_2026-03-24.md`
- Check: `SYSTEM_DOCS.md`

---

**Document Version:** 1.0
**Last Updated:** 2026-03-24
**Status:** ✅ Production Ready
