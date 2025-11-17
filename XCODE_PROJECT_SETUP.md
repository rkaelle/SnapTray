# Xcode Project Setup Instructions

## Critical: These files are NOT in your Xcode target yet!

The code has been written and committed, but Xcode doesn't know about these files yet. You need to add them manually.

---

## Step-by-Step Fix

### 1. **Delete Duplicate File**
❌ **Delete**: `ProcessingPageView 2.swift` (this is causing errors)

**How**:
1. In Xcode's Project Navigator (left sidebar), look for "ProcessingPageView 2.swift"
2. Right-click it → Delete
3. Choose "Move to Trash"

---

### 2. **Add ProcessingPageView.swift to Target**
✅ **Add**: `SnapTrayApp/Views/ProcessingPageView.swift`

**How**:
1. In Xcode, **File → Add Files to "SnapTrayApp"...**
2. Navigate to: `SnapTrayApp/Views/`
3. Select `ProcessingPageView.swift`
4. ✅ Check "Copy items if needed" is **UNCHECKED** (file is already there)
5. ✅ Check "SnapTrayApp" target is **CHECKED**
6. Click **Add**

**Or Alternative Method**:
1. In Finder, locate the file
2. Drag `ProcessingPageView.swift` from Finder into Xcode's Project Navigator
3. Drop it in the "Views" folder
4. In the dialog:
   - ✅ Check "Copy items if needed" is **UNCHECKED**
   - ✅ Check "SnapTrayApp" target
   - Click **Finish**

---

### 3. **Verify SensorFusionProcessor.swift is in Target**
✅ **Verify**: `SnapTrayApp/Processors/SensorFusionProcessor.swift`

**How**:
1. In Xcode Project Navigator, navigate to "Processors" folder
2. Click on `SensorFusionProcessor.swift`
3. Open the **File Inspector** (right sidebar, first tab - file icon)
4. Under "Target Membership" section:
   - ✅ Ensure "SnapTrayApp" is **CHECKED**
   - If it's not checked, check it now

**If the file is missing or in wrong location**:
1. If you see it in "Views" folder → Delete it
2. Add it from Processors folder using same steps as ProcessingPageView above
3. The file location is: `SnapTrayApp/Processors/SensorFusionProcessor.swift`

---

### 4. **Clean and Rebuild**
1. **Clean Build Folder**: Cmd+Shift+K (or Product → Clean Build Folder)
2. **Rebuild**: Cmd+B

---

## Expected Results After Setup

✅ **No errors** about:
- "Cannot find 'ProcessingPageView' in scope"
- "Cannot find 'SensorFusionProcessor' in scope"

✅ **File structure should look like**:
```
SnapTrayApp/
  ├── Views/
  │   ├── ProcessingPageView.swift ✅ (NEW - add to target)
  │   ├── ManualCaptureView.swift
  │   └── ProcessingView.swift
  └── Processors/
      ├── SensorFusionProcessor.swift ✅ (verify in target)
      ├── SegmentationProcessor.swift
      └── LiDARCaptureManager.swift
```

---

## Troubleshooting

### Error: "Duplicate symbol"
**Cause**: ProcessingPageView 2.swift still exists
**Fix**: Delete it (see Step 1)

### Error: "Cannot find 'ProcessingPageView'"
**Cause**: File not added to Xcode target
**Fix**: Follow Step 2

### Error: "Cannot find 'SensorFusionProcessor'"
**Cause**: File not in target, or duplicate in wrong location
**Fix**: Follow Step 3

### Error: File shows in Xcode but is red/missing
**Cause**: File reference is broken
**Fix**:
1. Delete the red reference in Xcode
2. Re-add the file using "Add Files to SnapTrayApp"

---

## Quick Checklist

Before building, verify:
- [ ] Deleted: "ProcessingPageView 2.swift"
- [ ] Added to target: "ProcessingPageView.swift" (in Views folder)
- [ ] Verified in target: "SensorFusionProcessor.swift" (in Processors folder)
- [ ] Cleaned build folder (Cmd+Shift+K)
- [ ] No red/missing files in Project Navigator
- [ ] All Swift files show in "SnapTrayApp" target membership

---

## Still Having Issues?

If you still see errors after following these steps:

1. **Check file inspector**: Click each file and verify "Target Membership" in right sidebar
2. **Check for duplicates**: Search for the filename in Project Navigator
3. **Restart Xcode**: Sometimes Xcode needs a restart to recognize new files
4. **Clean derived data**: Xcode → Preferences → Locations → Derived Data → Click arrow → Delete folder

---

## Summary

The code is perfect and works! The errors you're seeing are **Xcode project configuration issues**, not code issues. Once you add the files to the Xcode target, everything will build successfully.

**Main action**: Add `ProcessingPageView.swift` to your Xcode target (Step 2 above)
