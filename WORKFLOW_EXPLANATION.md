# Guided Camera iOS - End-to-End Workflow Explanation

## Overview
This document explains the complete end-to-end workflow of the Guided Camera iOS app, from workflow selection to final export.

## Complete Workflow Flow

### Phase 1: Setup & Workflow Loading

#### 1.1 App Launch & Permissions
- **Entry Point**: `SetupView` is the initial screen
- **Permissions**: On appear, `PermissionManager` requests:
  - Camera access (for photo/video capture)
  - Microphone access (for voice annotations)
  - Speech recognition (for STT)
  - Location (for geotagging media)

#### 1.2 Workflow Selection
- **User Choice**: Select from bundled workflows OR enter a custom URL
- **Bundled Workflows**: 
  - `WorkflowLoader.listBundledWorkflows()` searches for YAML files in bundle
  - Falls back to known workflows if bundle search fails
  - Displays: "Home Inspection", "Vehicle Accident", "Contractor Daily"
- **Custom URL**: 
  - User enters HTTPS URL
  - Validates URL format and security (HTTPS only)

#### 1.3 Workflow Loading
**Path**: `SessionManager.startSession()` → `WorkflowLoader.loadBundledWorkflow()`

1. **File Discovery**: Tries multiple methods to find YAML:
   - Bundle with subdirectory "Workflows"
   - Bundle without subdirectory
   - Resource URL path
   - Fallback to source directory (development)

2. **File Reading**: Loads YAML content as string
3. **Caching**: Caches YAML locally for offline use

#### 1.4 Workflow Compilation
**Path**: `WorkflowCompiler.compile()` → `GeminiService.compileWorkflow()`

1. **Cache Check**: Generates cache ID from YAML content hash
   - If cached plan exists, returns immediately (offline support)

2. **Gemini API Call**:
   - Sends YAML to Gemini 2.5 Flash with structured prompt
   - Prompt instructs Gemini to:
     - Normalize YAML to strict JSON structure
     - Map human phrases to known overlays/validators
     - Create deterministic state machine transitions
     - **CRITICAL**: Only reference actual step IDs in transitions

3. **Response Processing**:
   - Receives JSON plan from Gemini
   - Extracts JSON (removes markdown code blocks if present)
   - Decodes to `WorkflowPlan` model
   - Auto-generates `id` from `planId` if missing

4. **Validation & Auto-Fix**:
   - `WorkflowValidator.validate()`: Checks basic structure
   - `WorkflowValidator.validateAndFix()`: Auto-corrects invalid transitions
     - Removes transitions to non-existent step IDs
     - Adds default transitions if all were invalid
     - Last step can have empty transitions (completes naturally)

5. **Caching**: Saves compiled plan locally for future use

### Phase 2: Capture Session

#### 2.1 Session Initialization
**Path**: `CaptureSession.start()` → `SessionState` creation

1. **State Setup**:
   - Sets workflow plan
   - Initializes step index to 0
   - Sets state to `.active`
   - Records start timestamp

2. **Persistence**: Auto-saves to UserDefaults

#### 2.2 Camera Setup
**Path**: `CaptureView` appears → `CaptureManager.camera.startSession()`

1. **AVFoundation Setup**:
   - Creates `AVCaptureSession`
   - Configures video input (back camera)
   - Adds photo and video outputs
   - Starts session

2. **Preview Layer**: `CameraPreviewView` displays live camera feed

3. **Permissions**: Camera permission already requested in SetupView

#### 2.3 Step Execution Loop

For each step in the workflow:

**Step 1: Display Current Step**
- **Visual**: Shows step instruction text overlay
- **Voice**: `VoiceGuidanceEngine` speaks instruction via TTS
- **Overlays**: Displays visual guides (grid, horizon, rule of thirds) if specified
- **Progress**: Shows progress bar (step X of Y)

**Step 2: User Capture**
- User taps capture button
- `CaptureManager.capturePhoto()`:
  - `CameraController` captures image
  - Saves to `MediaStore` with metadata:
    - Session ID, Step ID
    - Device info
    - Location (if available)
  - Creates `CapturedMedia` object
  - Adds to session state

**Step 3: Validation**
- **Quality Validation**: `QualityValidator`
  - Checks sharpness, exposure against validators
  - Uses Vision framework for analysis
- **Scene Validation**: `SceneValidator`
  - Uses Vision framework to detect objects
  - Checks if required objects are present (e.g., "house", "car")
  - Validates against `labelsAnyOf` requirements

**Step 4: Feedback & Transition**
- **Success**: 
  - Voice: "Great! That looks good. Moving to the next step."
  - Visual: Green checkmark or success message
  - Transition: `CaptureSession.nextStep(transition: .onSuccess)`
- **Failure**:
  - Voice: "There's an issue: [error details]"
  - Visual: Error message with specific issues
  - User can retry or skip

**Step 5: State Machine Transition**
- `CaptureSession.nextStep()`:
  - Finds transition matching condition (onSuccess/onSkip)
  - Looks up next step ID in plan
  - Updates `currentStepIndex`
  - If no valid transition or last step: calls `complete()`
  - Auto-saves state

**Step 6: Repeat or Complete**
- If more steps: Loop back to Step 1
- If last step completed: `CaptureSession.complete()`
  - Sets state to `.completed`
  - Records completion timestamp
  - Saves final state

### Phase 3: Voice Annotation (Optional)

At any point during capture:

**Voice Annotation Flow**:
1. User triggers annotation (button or voice command)
2. `SpeechRecognizer.startRecognition()`:
   - Requests microphone access
   - Starts `SFSpeechRecognizer`
   - Captures audio input
3. **STT Processing**: Converts speech to text
4. **Annotation Creation**: `VoiceAnnotationManager`:
   - Creates `Annotation` object
   - Links to current step or specific media
   - Stores in `AnnotationStore`
5. **Session Update**: Adds annotation to session state

### Phase 4: Review & Export

#### 4.1 Review Screen
**Path**: `ReviewView` displays after session completion

1. **Media Review**: Lists all captured photos/videos
   - Shows step ID, timestamp
   - Thumbnail preview

2. **Annotation Review**: Lists all annotations
   - Shows type (voice/text/contextual Q&A)
   - Displays content

#### 4.2 Export Process
**Path**: `ReviewView.createExportPackage()`

1. **Package Creation**:
   - Creates temporary directory
   - Copies all media files to `media/` subdirectory
   - Creates `annotations.json` with all annotations
   - Attempts to create ZIP (simplified for Phase 1)

2. **Share Sheet**: 
   - Uses `UIActivityViewController`
   - User can share via AirDrop, email, Files app, etc.

## Data Flow Diagram

```
User Selection
    ↓
WorkflowLoader (YAML)
    ↓
WorkflowCompiler
    ↓
GeminiService (API) → JSON Plan
    ↓
WorkflowValidator (Auto-fix)
    ↓
WorkflowCache (Save)
    ↓
SessionManager → CaptureSession
    ↓
CaptureView (UI)
    ↓
CaptureManager → CameraController
    ↓
MediaStore (Save files)
    ↓
QualityValidator + SceneValidator
    ↓
CaptureSession.nextStep()
    ↓
[Repeat for each step]
    ↓
Session Complete
    ↓
ReviewView
    ↓
Export Package
```

## State Machine Details

### Session States
- **idle**: Initial state, no active workflow
- **active**: Workflow in progress, capturing steps
- **paused**: User paused (can resume)
- **completed**: All steps finished

### Transition Logic
1. **Valid Transition**: Points to existing step ID → Navigate to that step
2. **Invalid Transition**: Points to non-existent step ID → Auto-fixed by validator
3. **No Transition**: Last step or missing transitions → Complete session
4. **Default Fallback**: If transition fails → Move to next step in sequence

### Step Progression
- **Success Path**: `onSuccess` → Next step (or complete)
- **Skip Path**: `onSkip` → Next step (or complete)
- **Retry Path**: User retries → Stay on current step, clear captured media

## Error Handling

### Workflow Loading Errors
- **File Not Found**: Tries multiple paths, shows error if all fail
- **Invalid YAML**: Rejected by Gemini, error shown to user

### Compilation Errors
- **API Errors**: Retry with exponential backoff (429 rate limits)
- **Invalid JSON**: Detailed decoding error logged
- **Missing Fields**: Auto-generated (id from planId)

### Validation Errors
- **Invalid Transitions**: Auto-removed and replaced with defaults
- **Missing Steps**: Cannot fix, throws error
- **Duplicate IDs**: Cannot fix, throws error

### Capture Errors
- **Camera Failure**: Error message, user can retry
- **Validation Failure**: Specific error feedback, user can retry or skip
- **Storage Failure**: Error message, session continues

## Caching Strategy

### YAML Caching
- **Remote Workflows**: Cached after first fetch
- **Location**: `Caches/Workflows/[filename].yaml`
- **Offline**: Can load cached YAML without network

### Compiled Plan Caching
- **Key**: Hash of YAML content
- **Location**: `Caches/Workflows/plan_[hash].json`
- **Offline**: Can use cached plan without re-compiling
- **Invalidation**: Only on YAML content change

### Session State Caching
- **Location**: UserDefaults
- **Auto-save**: After every step completion
- **Resume**: Can resume paused sessions

## Key Components Interaction

```
SetupView
  → SessionManager.startSession()
    → WorkflowLoader.loadBundledWorkflow()
    → WorkflowCompiler.compile()
      → GeminiService.compileWorkflow()
      → WorkflowValidator.validateAndFix()
    → CaptureSession.start()
  → CaptureView (sheet)
    → CaptureManager.camera.startSession()
    → GuidanceCoordinator.provideGuidance()
    → User captures photo
    → QualityValidator + SceneValidator
    → CaptureSession.nextStep()
    → [Loop until complete]
  → ReviewView
    → Export package
```

## Summary

The app follows a clear pipeline:
1. **Load** YAML workflow (local or remote)
2. **Compile** via Gemini API to executable JSON plan
3. **Validate & Fix** any issues (especially invalid transitions)
4. **Execute** step-by-step with real-time guidance
5. **Validate** each capture against requirements
6. **Progress** through state machine
7. **Complete** and export results

The system is designed to be resilient:
- Auto-fixes invalid transitions
- Caches for offline use
- Graceful error handling
- Manual overrides (skip/retry)

