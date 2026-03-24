# Orascan Codebase Analysis

## Project Overview
Orascan is a diagnostic system for oral health, consisting of a Go-based cloud backend and Python-based desktop applications designed for edge devices (likely Raspberry Pi) equipped with specialized sensors and motorized camera mounts.

## Architecture & Technology Stack

### 1. Backend (`OraScan_backend`)
- **Language**: Go
- **Framework**: [Gin Gonic](https://github.com/gin-gonic/gin)
- **Database**: PostgreSQL (Metadata, Users, Scan links)
- **Storage**: Azure Blob Storage (Patient images)
- **Authentication**: JWT (JSON Web Tokens) with Bcrypt password hashing
- **Key Files**:
    - `main.go`: Entry point, initializes Postgres and Azure clients.
    - `api.go`: Defines REST endpoints (`/register`, `/login`, `/upload`).
    - `type.go`: Shared data models (User, PatientImage).

### 2. Desktop Applications (`OraScan_Automated_Scanning` & `OraScan_Manual_Scanning`)
- **Core Stack**: 
    - **Language**: Python 3
    - **UI**: [ReactPy](https://reactpy.dev/) (React-like component architecture in Python)
    - **API Shell**: [FastAPI](https://fastapi.tiangolo.com/)
    - **Desktop Wrapper**: [PyWebView](https://pywebview.flowrl.com/) (wraps HTML/JS in a native window)
- **Hardware Integration**:
    - **Camera**: OpenCV (`cv2`) for real-time oral photo acquisition.
    - **Motor Control**: `motor_driver.py` (PWM for Servos and Steppers via `lgpio` and `HR8825`). Currently contains logic for 13 predefined scanning positions.
    - **Sensors**: Breath sensor (H2S detection) and Audio recording (PyAudio).
- **Database**: Currently uses **MySQL** (via `pymysql`) for local patient management and report history.
- **Key Files**:
    - `main.py`: Starts FastAPI/Uvicorn and launches the PyWebView window.
    - `dashboard_page.py`: Main user interface components.
    - `oral_photo_acquisition_page.py`: Interactive camera feed and motor controls.

### 3. Face & Oral Monitoring (`OraScan-Facemesh`)
- **Technology**: [MediaPipe Facemesh](https://google.github.io/mediapipe/solutions/face_mesh.html)
- **Functionality**:
    - `mouth.py`: Detects mouth open/closed status by calculating the distance between lip landmarks.
    - `smile.py` & `tongue.py`: Likely handle expression detection and tongue protrusion analysis.

## Key Observations & Insights

### 1. Hybrid Storage Strategy
The system appears to be transitioning between local and cloud storage. The Go backend is built for Azure/Postgres, while the Python apps still have deep integration with local MySQL (`database_utils.py`).

### 2. Hardware Abstraction
The `motor_driver.py` is written to be cross-platform, using mocks for Mac/Windows testing while having hardware-specific code (commented out) for Raspberry Pi GPIO interaction.

### 3. Predefined Scanning Sequences
The system uses a sophisticated `SERVO_POSITIONS` and `STEPPER_POSITIONS` array in `motor_driver.py` to automate the oral scanning process, ensuring consistency across different patient exams.

### 4. Modular UI
ReactPy allows for a modular, component-based UI approach within a Python environment, making it easier to manage the complex states of hardware interaction (calibration, scanning, uploading).

## Recommendations
- **Unified Database**: Align the edge devices to use the Go backend API for all operations rather than direct MySQL connections to avoid data silos.
- **Error Handling**: Enhance hardware initialization checks (e.g., `camera.isOpened()`) to provide better user feedback when sensors are disconnected.
- **Facemesh Integration**: Integrate the `Facemesh` scripts directly into the `OralPhotoAcquisitionPage` to provide real-time guidance to patients (e.g., "Please open your mouth wider").
