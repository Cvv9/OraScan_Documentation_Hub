# OraScan GUI Architecture & Pages Breakdown

## 1. Architectural Overview

The OraScan desktop application uses a python-driven modern web stack wrapped as a native application:

- **Frontend Layer:** `ReactPy` (Python implementation of React-like components) creates interactive DOM elements.
- **Styling:** Inline CSS with modern principles (Glassmorphism, hover animations, drop shadows, responsive grids).
- **Backend & Serving:** `FastAPI` serves the static assets and handles async event processing.
- **Window Wrapper:** `pywebview` launches the application locally as a native Windows desktop GUI (`1024x768`, maximized).

## 2. Routing Logic

Routing is handled centrally within `main.py` using ReactPy's `use_state` hook:

- A root `current_path` state tracks the active route (default: `"/login"`).
- Components mutate the view by calling the `set_current_path(new_route)` callback.
- Global authentication is protected implicitly in `main.py`; paths like `/dashboard` and `/oral-photo-acquisition` wrap responses in an `if user:` check, issuing a `RedirectResponse` to `/login` if no active session is found.

---

## 3. Individual Pages & Elements Detailed Breakdown

### A. Login Component (`/login`)

- **Visuals:** Split-screen layout. A semi-transparent white "glass" form sits centrally on the right, backed by a prominent background (`Mainpage.jfif`).
- **Elements:**
  - `html.input` for **Email**.
  - `html.input` for **Password**.
  - Big blue **"Login"** submit button (`html.button`).
  - Sub-links for **"Create Account"** and **"Forgot Password?"**.
  - Dynamic red text element for error handling.
- **Interactions:** Invokes `fetch_user_details()`. Upon success (including legacy DB integrations and backend API checks), it pushes details into the main `user` state block and transitions to `/dashboard`. Interacts with `/register` and `/forgot-password` via sublinks.

### B. Dashboard Page (`/dashboard`)

- **Visuals:** Standard modern application structure; locked 280px left sidebar and a flexible main content area covered with a wallpaper (`dashboardwp.jfif`).
- **Left Sidebar Elements:**
  - Sticky Logo and "DashBoard" text heading.
  - Unordered list (`ul/li`) navigation menu tracking:
    - **Profile** (`/profile`)
    - **Scan History** (`/scan-history`)
    - **Past Reports** (`/view-past-reports`)
    - **Health Tips** (`/oral-health-tips`)
    - **Settings** (`/settings`)
    - **Logout** (`/logout`)
- **Main Interaction Area:**
  - "Glassmorphism" styled top greeting header with logged-in user's first name and a circular Avatar image.
  - A responsive CSS Grid containing **4 Primary Action Cards**. Each card features a distinct icon, title, description, and hover interactions (scale/translate/shadows).
    - **Start New Scan Card:** Routes to `/oral-photo-acquisition`
    - **Record Audio Data Card:** Routes to `/audio-data`
    - **Record Breath Data Card:** Routes to `/breath-data`
    - **Questionnaire Card:** Routes to `/questionnaire`

### C. Oral Photo Acquisition Page (`/oral-photo-acquisition`)

- **Visuals:** Clinical environment splitting controls (left) and capture preview mapping (right).
- **Sidebar Elements (Controls):**
  - **"Back to Dashboard"** toggle button.
  - **"Start Full Scan Sequence"** button (Green active, Grey disabled).
  - Text prompts dynamically displaying progression ("Capturing 1/13").
  - **"✅ Submit Session"** button (Invisible until 13 captures populate).
- **Main Area Elements (Live Capture):**
  - **Instruction Cluster (Top Strip):** Splits horizontally showing:
    - Textual Instructions ("Say aaah! Pull cheek...").
    - Static Reference Image ("How it should look").
    - Demonstration GIF ("How to position yourself/camera").
  - **Gallery Grid (Bottom area):** A 13-slot array representing sequence angles (Front teeth, tongue, left/right alignments). Slots dynamically switch from empty integers (`[ 1 ]`) to an `html.img` rendering `captured_images` array elements.
- **Interactions:**
  - Clicking "Start Sequence" kicks off an asynchronous hardware loop targeting `perform_capture_step()`. Uses physical motor/robotic coordinates targeting `cv2.VideoCapture` indices.
  - The UI locks down until hardware stops streaming.
  - Clicking "Submit Session" extracts all `filename.jpg` strings from dict and posts physical local files to FastAPI via `upload_images`.

### D. Audio Recording Page (`/audio-data`)

- **Visuals:** Highly focused single-action card floated centrally on screen (`AudioDataBGpage.jfif`).
- **Elements:**
  - Back contextual button.
  - Detailed instructional lists outlining patient jaw articulation steps.
  - A prominent large red **"Start Recording"** button displaying a pulsing style.
  - Conditional status text string (Orange/Green colors).
- **Interactions:** Binds an `AudioRecorder` thread object. Captures 20 seconds of sound via machine microphone without stalling the main UI loop, dumping binary `wav` blobs directly into the Postgres instance over HTTP.

### E. Breath Analysis Page (`/breath-data`)

- **Visuals:** Nearly identical card template layout to Audio (assuring UI conformity), distinct `BreathData.jfif` background.
- **Elements:**
  - Instructions list specifying how to blow/exhale into the port.
  - Red **"Start Analysis"** Action Button.
  - Large font **Readout Data Label** (Displays XX ppb). Turns Green (<80) or Red (>80).
- **Interactions:** Instantiates a `BreathSensor()` hardware hook. Once button clicked, asynchronous await loop captures roughly 8 seconds of H2S sensor metrics via specific serial IO, passing integer strings straight to `ensure_h2s_column()` DB queries.

### F. Peripheral Modules

Core design systems mapped loosely based on dashboard routing options limit:

- **Register (`/register`) / Forgot Password (`/forgot-password`):** Simple form templates matching `LoginPage` schema for Auth resets.
- **Profile / Settings (`/profile`, `/settings`):** Renders form structures to map local SQL configurations via variables tied heavily to `user_details` state JSON.
- **Forms & Read-Only Context (`/questionnaire`, `/oral-health-tips`, `/scan-history`, `/view-past-reports`):** Generic list views looping SQL arrays to build table items or text paragraphs for legacy results.
