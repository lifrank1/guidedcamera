# Camera Preview Best Practices - iOS AVFoundation

## The Problem: Gray Screen Instead of Camera

### Common Causes

1. **Preview Layer Not Properly Configured**
   - Creating new preview layer each time instead of reusing
   - Frame not set correctly (especially initial `.zero` frame)
   - Layer not added to view hierarchy properly

2. **Session Not Running**
   - Camera session not started when preview appears
   - Session stopped or not configured

3. **Permissions Not Granted**
   - Camera permission denied or not requested
   - Permission check happens after view setup

4. **Threading Issues**
   - Camera session operations on wrong thread
   - UI updates not on main thread

5. **View Lifecycle Issues**
   - Preview layer created before view has bounds
   - Frame updates not happening in `layoutSubviews`

## The Solution: Industry Best Practices

### 1. Use Custom UIView with AVCaptureVideoPreviewLayer as Layer Class

**Why**: This ensures the preview layer is the view's backing layer, not a sublayer. This is more efficient and handles frame updates automatically.

```swift
class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}
```

### 2. Set Up Session Before Preview

**Why**: The preview layer needs an active session to display video.

```swift
func setupPreviewLayer(with controller: CameraController) {
    videoPreviewLayer.session = controller.captureSession
    videoPreviewLayer.videoGravity = .resizeAspectFill
}
```

### 3. Update Frame in layoutSubviews

**Why**: Ensures the preview layer always matches the view's bounds, especially after rotation or layout changes.

```swift
override func layoutSubviews() {
    super.layoutSubviews()
    videoPreviewLayer.frame = bounds
}
```

### 4. Check Permissions Before Setup

**Why**: Prevents setup failures and provides better error handling.

```swift
private func checkPermissionsAndSetup() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
        setupSession()
    case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if granted {
                self.setupSession()
            }
        }
    default:
        error = .setupFailed
    }
}
```

### 5. Start Session After View Appears

**Why**: Ensures the view is fully laid out before starting the camera session.

```swift
.onAppear {
    // Small delay to ensure view is laid out
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        cameraController.startSession()
    }
}
```

### 6. Handle Session on Background Thread

**Why**: Starting/stopping the session can block, so it should be on a background thread, but UI updates must be on main thread.

```swift
func startSession() {
    DispatchQueue.global(qos: .userInitiated).async {
        self.session.startRunning()
        DispatchQueue.main.async {
            self.isSessionRunning = true
        }
    }
}
```

## What I Fixed

1. **Custom UIView**: Changed from adding preview layer as sublayer to using it as the backing layer
2. **Frame Updates**: Added `layoutSubviews` to ensure frame is always correct
3. **Permission Check**: Added explicit permission checking before setup
4. **Session Timing**: Added delay before starting session to ensure view is laid out
5. **Better Logging**: Added comprehensive logging to debug camera issues
6. **Error Handling**: Improved error handling with specific error messages

## Testing Checklist

- [ ] Camera permission granted
- [ ] Session starts successfully (check logs)
- [ ] Preview layer frame matches view bounds
- [ ] Camera feed visible (not gray)
- [ ] Works on both simulator (if supported) and device
- [ ] Handles orientation changes
- [ ] Properly stops when view disappears

## Debugging Tips

1. **Check Logs**: Look for camera setup messages in console
2. **Verify Permissions**: Settings → Privacy → Camera
3. **Check Session State**: `isSessionRunning` should be `true`
4. **Verify Frame**: Preview layer frame should match view bounds
5. **Test on Device**: Simulator may not show camera preview

## Industry Standard Pattern

The pattern I implemented follows Apple's recommended approach:

1. **Custom UIView** with `AVCaptureVideoPreviewLayer` as layer class
2. **Single session instance** shared between controller and preview
3. **Permission-first** setup flow
4. **Lifecycle-aware** session management (start on appear, stop on disappear)
5. **Thread-safe** operations (session on background, UI on main)

This is the same pattern used in Apple's sample code and recommended in WWDC sessions.

