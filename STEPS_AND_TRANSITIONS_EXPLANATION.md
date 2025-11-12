# Steps and Transitions Explained

## What is a Step?

A **step** is a single task in a workflow that the user needs to complete. Each step has:

- **ID**: Unique identifier (e.g., "exterior_wide", "front_door")
- **Instruction**: What the user should do (e.g., "Take a wide shot of the front of the house")
- **Capture Type**: Photo or video
- **Validators**: Rules to check if the capture is good (e.g., must contain "house", sharpness > 0.4)
- **Overlays**: Visual guides (grid, horizon, rule of thirds)
- **Transitions**: Where to go next after completing this step

## What is a Transition?

A **transition** is a rule that says "after this step, go to that step". It has:

- **When**: The condition that triggers it
  - `onSuccess`: User captured a good photo that passed validation
  - `onSkip`: User skipped this step
  - `onFailure`: User's photo failed validation (optional)
  
- **To**: The ID of the next step to go to

## Example Workflow Structure

```
Step 1: "exterior_wide"
  ├─ Instruction: "Take a wide shot of the front of the house"
  ├─ Validators: Must contain "house" or "building"
  └─ Transitions:
      ├─ onSuccess → "front_door"  (go to step 2)
      └─ onSkip → "front_door"     (go to step 2)

Step 2: "front_door"
  ├─ Instruction: "Capture a close-up photo of the front door"
  └─ Transitions:
      ├─ onSuccess → "roof_inspection"  (go to step 3)
      └─ onSkip → "roof_inspection"    (go to step 3)

...

Step 6: "bathroom_check" (LAST STEP)
  ├─ Instruction: "Photograph each bathroom"
  └─ Transitions: []  (EMPTY - this is OK! Session completes)
```

## Why the Last Step Has No Transitions

The **last step** in a workflow doesn't need transitions because:

1. **Natural Completion**: When the user finishes the last step, the session automatically completes
2. **No Next Step**: There's nowhere to go after the last step
3. **Session Logic**: The `CaptureSession.nextStep()` function handles this:
   - If no transition found → Check if it's the last step → Complete session
   - If not last step → Move to next step in sequence

## What Was Going Wrong?

### The Problem

The validator was checking that **ALL steps** must have at least one transition. But the last step (index 5, "bathroom_check") had empty transitions `[]`, which is actually correct behavior.

### The Fix

I updated the validator to:
- **Allow** the last step to have empty transitions
- **Require** all other steps to have at least one transition
- **Auto-fix** invalid transitions (pointing to non-existent steps)

## How Gemini Generates Transitions

Gemini looks at the YAML workflow and creates transitions like this:

**YAML Input:**
```yaml
steps:
  - id: step1
    instruction: "Take photo"
  - id: step2
    instruction: "Take another photo"
```

**Gemini Output (JSON):**
```json
{
  "steps": [
    {
      "id": "step1",
      "transitions": [
        {"when": "onSuccess", "to": "step2"},
        {"when": "onSkip", "to": "step2"}
      ]
    },
    {
      "id": "step2",
      "transitions": []  // Last step - empty is OK
    }
  ]
}
```

## Current Behavior

1. **Gemini generates the plan** with transitions
2. **Validator checks** the plan structure
3. **Auto-fix removes** invalid transitions (like "workflow_complete")
4. **Last step** is allowed to have empty transitions
5. **Session executes** step by step
6. **When last step completes** → Session automatically completes

## State Machine Flow

```
Start Session
    ↓
Step 1 (exterior_wide)
    ↓ [onSuccess/onSkip]
Step 2 (front_door)
    ↓ [onSuccess/onSkip]
Step 3 (roof_inspection)
    ↓ [onSuccess/onSkip]
Step 4 (interior_entry)
    ↓ [onSuccess/onSkip]
Step 5 (kitchen_overview)
    ↓ [onSuccess/onSkip]
Step 6 (bathroom_check) ← LAST STEP
    ↓ [no transitions needed]
Session Complete ✅
```

## Summary

- **Step**: A single task in the workflow
- **Transition**: A rule saying "go to step X after this step"
- **Last Step**: Can have empty transitions (session completes naturally)
- **Validator**: Now allows last step to have no transitions
- **Gemini**: Sometimes generates empty transitions for last step (this is correct!)

The fix I made allows the last step to have empty transitions, which is the correct behavior. The workflow should now work properly!

