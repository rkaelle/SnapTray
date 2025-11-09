# SnapTray Complete Setup Walkthrough

This guide will walk you through everything you need to get started with SnapTray, from zero to your first printed tray.

---

## What You Need

### Required Hardware

1. **iPhone with LiDAR**
   - iPhone 12 Pro, 13 Pro, 14 Pro, 15 Pro (or Pro Max variants)
   - iPad Pro (2020 or later)
   - Check: Settings → General → About → Model (must have LiDAR sensor)

2. **Fiducial Markers** (one of these options):
   - 4 US Quarters + ArUco markers (recommended)
   - 4 ArUco markers alone
   - 4 US Quarters alone (less accurate)

3. **Background Surface**
   - Black foam board (18" × 24" or larger) - $5 at craft stores
   - OR black poster board
   - OR black fabric on flat surface
   - Key: Matte finish, not glossy

4. **Lighting**
   - LED desk lamp or overhead light
   - Diffuse (no harsh shadows)
   - NOT direct sunlight

### Optional (for manufacturing)

5. **3D Printer**
   - Ender 3 V3 Plus (recommended)
   - Any FDM printer with 200×200mm+ bed
   - PLA filament

6. **Computer**
   - Mac or PC with slicer software (Cura, PrusaSlicer)
   - OR laser/CNC software for foam cutting

---

## Step-by-Step Setup

### Part 1: Install the App (10 minutes)

#### Option A: Build from Source (Developer)

1. **Install Xcode** (if not already):
   ```bash
   # Open Mac App Store
   # Search "Xcode"
   # Install (it's free, but ~15GB download)
   ```

2. **Clone SnapTray**:
   ```bash
   cd ~/Projects
   git clone https://github.com/yourusername/SnapTray.git
   cd SnapTray
   ```

3. **Open in Xcode**:
   ```bash
   open SnapTrayApp.xcodeproj
   ```

4. **Trust Developer Certificate**:
   - Click "SnapTrayApp" in left sidebar
   - Go to "Signing & Capabilities" tab
   - Under "Team", select your Apple ID
   - If you don't see your ID, click "Add Account" and sign in

5. **Connect iPhone**:
   - Plug in via USB-C or Lightning
   - Unlock iPhone
   - Tap "Trust This Computer" on iPhone

6. **Build & Run**:
   - Select your iPhone from device dropdown (top toolbar)
   - Click Run button (▶️) or press ⌘R
   - First time: iPhone will show "Untrusted Developer"
   - On iPhone: Settings → General → VPN & Device Management → Trust your Apple ID

#### Option B: TestFlight (Coming Soon)
- Public beta link will be available here when released

---

### Part 2: Create Fiducial Markers (15 minutes)

Fiducials help SnapTray establish accurate scale and workspace boundaries.

#### Method 1: ArUco + Quarters (RECOMMENDED)

This gives the best accuracy - visual markers + physical scale reference.

1. **Print ArUco Markers**:
   ```bash
   # From the SnapTray directory
   open docs/aruco_markers.pdf
   ```

   **Print settings** (IMPORTANT):
   - Page scaling: **None** (100% scale)
   - NOT "Fit to page"
   - NOT "Shrink oversized pages"
   - Print on regular paper (white, letter/A4)

2. **Cut Out Markers**:
   - Cut along the outer black border
   - Each marker should be exactly 50mm × 50mm
   - Use a ruler and X-acto knife for clean edges
   - You need all 4 markers (IDs: 0, 1, 2, 3)

3. **Attach to Quarters**:
   - Get 4 US quarters (25¢ coins)
   - Use clear tape or glue stick
   - Center marker on the "heads" side of coin
   - Make sure marker is flat, not wrinkled

4. **Label them** (optional but helpful):
   - Top-left, Top-right, Bottom-left, Bottom-right
   - Or just: 1, 2, 3, 4

**Result**: You now have 4 fiducial markers with physical scale reference

#### Method 2: Quarters Only (Quick & Easy)

1. **Get 4 US Quarters**:
   - They must be US quarters (24.26mm diameter)
   - Canadian quarters are slightly different size
   - Clean them (so they're shiny and easy to detect)

**Result**: Simple but slightly less accurate

#### Method 3: ArUco Only (No Coins)

Same as Method 1, but skip the quarters. Less accurate scale, but still works.

---

### Part 3: Set Up Your Scanning Station (10 minutes)

#### 3.1: Prepare Background

1. **Surface**:
   - Use a table, workbench, or floor
   - Must be flat and stable
   - Size: At least 12" × 18" (30cm × 45cm)

2. **Background Material**:
   - Lay down black foam board
   - Smooth it out (no wrinkles or bubbles)
   - Tape corners down if needed

**Why black matte?**
- High contrast with metal/plastic tools
- Doesn't reflect LiDAR (prevents noise)
- Easy for computer vision to separate tools from background

#### 3.2: Lighting Setup

**Good lighting**:
- Overhead LED panel
- LED desk lamp pointed at ceiling (bounced)
- Cloudy day near a window (diffuse)

**Bad lighting**:
- Direct sunlight (too harsh, creates deep shadows)
- Single point light (creates hard shadows)
- Dim/dark room (poor camera quality)

**Test**: Take a photo of the background. If you see harsh shadows or blown-out highlights, adjust lighting.

#### 3.3: Camera Position

You'll need to hold your iPhone **60-100cm (2-3 feet)** above the surface.

**Tips for stability**:
- Use both hands
- Rest elbows on a surface if possible
- OR use a tripod with phone mount (ideal)
- Keep phone parallel to surface (not angled)

---

### Part 4: First Scan (Test Run) (15 minutes)

Let's do a practice scan with just a few tools to test your setup.

#### 4.1: Arrange Test Layout

1. **Place fiducials**:
   ```
   [1]                    [2]



   [3]                    [4]
   ```
   - Put markers at 4 corners of your intended workspace
   - Spacing: ~150-250mm apart
   - Doesn't need to be perfect rectangle

2. **Place 2-3 tools**:
   - Start with simple tools (wrench, screwdriver, pliers)
   - Lay them FLAT (not standing up)
   - Leave 10-20mm gap between tools
   - Keep them inside the fiducial boundary

**Example layout**:
```
[Marker]  . . . . . . . . . [Marker]
   .                              .
   .      [Wrench]                .
   .                              .
   .              [Pliers]        .
   .                              .
[Marker]  . . . . . . . . . [Marker]
```

#### 4.2: Capture

1. **Open SnapTray** app on your iPhone

2. **Tap "Start New Scan"**

3. **Position phone**:
   - Hold 60-100cm above the center of your layout
   - Keep parallel to surface
   - You should see the full workspace on screen

4. **Wait for detection**:
   - Green "Plane detected" indicator will appear
   - If it doesn't appear after 5 seconds:
     - Move phone up/down slightly
     - Ensure room is well-lit
     - Check that background is visible

5. **Capture**:
   - Tap the big camera button
   - Hold VERY still for 2-3 seconds
   - App will show "Processing scan..."

#### 4.3: Review Results

The app will show detected tools with colored outlines.

**Check**:
- ✅ All tools detected? (should see 2-3 outlined)
- ✅ Fiducials detected? (check top bar)
- ✅ Outlines match tool shapes?

**If something's wrong**:
- Tap "Back" and adjust lighting/layout
- Make sure tools are flat and separated
- Ensure background has good contrast

#### 4.4: Adjust Settings

1. **Tap any tool** to edit:
   - Add a label: "Test Wrench"
   - Check depth looks reasonable (e.g., 10-15mm for a wrench)
   - Leave other settings at defaults for now

2. **Tap gear icon** for tray settings:
   - Material: PLA (default)
   - Tray thickness: 12mm (default)
   - Leave interference at -0.25mm

3. **Tap "Continue"** when ready

#### 4.5: Export Test Files

1. **Tap "PDF Report with Scale"** first

2. **Share** → **Save to Files** (or AirDrop to Mac)

3. **Print the PDF**:
   - Page 3 has scale calibration template
   - Print at **100% scale** (check printer settings!)
   - Use "Actual Size" NOT "Fit to Page"

4. **Verify scale**:
   - Use a ruler to measure the 100mm scale bar on printed page
   - Should measure exactly 100mm
   - If off by >2mm, adjust printer settings and reprint

**If scale is correct**: Your setup is perfect! ✅

**If scale is wrong**: See troubleshooting section below

---

### Part 5: Export & 3D Print (30 minutes)

#### 5.1: Export STL

1. In export screen, tap **"STL for 3D Printing"**

2. Tap **Share button** on exported file

3. **AirDrop to Mac** (or use Files → iCloud Drive)

#### 5.2: Slice for Printing

1. **Open your slicer** (Cura, PrusaSlicer, etc.)

2. **Import STL**:
   - Drag STL file into slicer
   - Should appear on build plate

3. **Use these settings** (Ender 3 V3 Plus):
   ```
   Material: PLA
   Layer Height: 0.2mm
   Wall Line Count: 4
   Infill: 15% (Grid or Gyroid)

   Print Temperature: 205°C
   Bed Temperature: 60°C

   Print Speed: 50mm/s
   First Layer Speed: 20mm/s

   Build Plate Adhesion: Brim (5mm)
   Support: None needed
   ```

4. **Slice** and check estimated time

5. **Save G-code** to SD card or send directly to printer

#### 5.3: Print

1. **Prepare printer**:
   - Level bed
   - Clean bed with isopropyl alcohol
   - Load PLA filament

2. **Start print**

3. **Watch first layer**:
   - Should stick well with no gaps
   - If not sticking: re-level bed
   - If too squished: raise Z-offset

4. **Print time**: ~2-4 hours for a typical tray

#### 5.4: Remove & Test

1. **Let cool** (5-10 minutes) before removing

2. **Remove brim** with hobby knife or pliers

3. **Test fit your tools**:
   - Should slide in with light pressure
   - Should stay in place when tray is tilted 45°

**Too tight?**
- Increase XY interference in app (e.g., -0.25 → -0.15)
- Rescan and print again

**Too loose?**
- Decrease XY interference (e.g., -0.25 → -0.35)
- Rescan and print again

---

## Troubleshooting Common Issues

### Scanning Problems

#### "Plane not detected"

**Cause**: ARKit can't lock onto the surface

**Solutions**:
1. Improve lighting (brighter, more diffuse)
2. Hold phone more level (parallel to surface)
3. Move phone up/down slowly to help detection
4. Ensure there's visible texture (not pure white/black)
5. Try scanning a different area first, then move to your layout

#### "No fiducials detected"

**Cause**: Markers aren't visible or recognizable

**Solutions**:
1. Check markers are in camera view
2. Make sure markers are flat (not wrinkled or shadowed)
3. Increase contrast (better lighting)
4. Print markers larger (60mm × 60mm)
5. Use quarters as backup (ensure they're visible)

#### "Tools not detected" or "Only some tools detected"

**Cause**: Low contrast or tools too close together

**Solutions**:
1. Increase spacing between tools (20mm+)
2. Use darker background
3. Ensure tools are completely flat
4. Remove very small tools (< 20mm)
5. Clean/polish shiny tools (reduce reflections)

#### "Scale seems wrong"

**Cause**: Fiducial detection error

**Solutions**:
1. Print PDF calibration page and measure with ruler
2. Verify quarters are US quarters (24.26mm)
3. Ensure ArUco markers printed at exact 50mm × 50mm
4. Rescan with fiducials farther apart
5. Use all 4 markers, not just 2-3

### Export Problems

#### "STL won't open in slicer"

**Cause**: File corruption or incompatibility

**Solutions**:
1. Update your slicer to latest version
2. Try a different slicer (Cura is most compatible)
3. Open in 3D viewer first (Windows 3D Viewer, macOS Preview)
4. Re-export STL from app
5. Check file size (should be >100KB)

#### "DXF looks wrong in CAD software"

**Cause**: Multiple layers or units mismatch

**Solutions**:
1. Turn off all layers except `TOOL_X_POCKET`
2. Check units are set to millimeters
3. Scale might be set to inches (multiply by 25.4)
4. Use a different CAD viewer
5. Re-export DXF and check file

### Printing Problems

#### "First layer won't stick"

**Solutions**:
1. Re-level bed (paper test)
2. Clean bed with isopropyl alcohol
3. Increase bed temperature (+5°C)
4. Slow down first layer (15mm/s)
5. Add brim or raft

#### "Warping on corners"

**Solutions**:
1. Lower bed temperature (prevent over-heating)
2. Add larger brim (10mm)
3. Add "mouse ears" to corners
4. Use glue stick on bed
5. Ensure room is not drafty

#### "Tools don't fit (too tight)"

**Cause**: Interference setting too aggressive

**Solutions**:
1. In app: Settings → Material → XY Interference
2. Increase by +0.1mm increments
3. Test: -0.25 → -0.15 → -0.05
4. Print a small test tray first
5. Keep notes on what works for your printer

#### "Tools are too loose"

**Cause**: Interference too permissive

**Solutions**:
1. Decrease XY interference by -0.1mm
2. Test: -0.25 → -0.35 → -0.45
3. Check if printer is over-extruding (calibrate e-steps)
4. Reduce flow rate to 95%

#### "Rough pocket surfaces"

**Cause**: Layer height too high or poor calibration

**Solutions**:
1. Reduce layer height (0.2 → 0.15 → 0.12mm)
2. Calibrate flow and e-steps
3. Dry filament (PLA absorbs moisture)
4. Increase wall count (4 → 5 or 6)
5. Slow down print speed

---

## Tips for Best Results

### Scanning

1. **Use a tripod**: Attaching your iPhone to a tripod eliminates hand shake
2. **Batch similar tools**: Scan wrenches together, sockets together, etc.
3. **Label as you go**: Name tools during review (easier than remembering later)
4. **Take photos**: Document your layout before scanning (for reference)

### Design

1. **Leave margins**: Keep 10-15mm from drawer edges
2. **Group by frequency**: Most-used tools in front/center
3. **Consider access**: Longer tools near drawer front for easy removal
4. **Test depths**: Shallow pockets (5-8mm) work for many tools

### Printing

1. **Print test pieces**: Small 2-tool tray to verify settings
2. **Use quality filament**: Cheap PLA can have dimensional issues
3. **Dry filament**: Store in sealed bags with desiccant
4. **Keep notes**: Record settings that work for YOUR printer
5. **Calibrate regularly**: E-steps, flow, temperature tower

### Materials

1. **PLA**: Easiest, best for most users
2. **PETG**: Tougher, better for heavy tools
3. **TPU**: Grippy, great for delicate tools (bits, precision drivers)
4. **Foam**: Best for portable toolboxes (vibration resistant)

---

## Next Steps

### Once Your Setup Works

1. **Scan your full toolbox**:
   - One drawer at a time
   - Take your time with layout
   - Label everything

2. **Experiment with settings**:
   - Try different materials
   - Adjust interference for perfect fit
   - Test drain holes for outdoor use

3. **Share your designs**:
   - Export DXF/STL
   - Upload to Thingiverse, Printables
   - Help the community!

### Advanced Techniques

1. **Multi-material printing**:
   - TPU base + PLA walls
   - Dual-color for labels

2. **Embedded magnets**:
   - Enable "magnet cavities" in settings
   - Glue 6mm × 2mm magnets in cavities
   - Tool retention for mobile toolboxes

3. **Drawer dividers**:
   - Add tray thickness to existing drawer foam
   - Stack multiple trays

4. **Custom modifications**:
   - Import STL into Fusion 360
   - Add hooks, clips, or custom geometry
   - Re-export and print

---

## Getting Help

### Resources

- **README.md**: Full feature documentation
- **GitHub Issues**: Report bugs or request features
- **Discussions**: Ask questions, share tips

### Common Questions

**Q: Can I scan tools vertically?**
A: No, tools must be flat. Vertical scanning would lose the top-down view needed for tray pockets.

**Q: What's the maximum number of tools per scan?**
A: Tested up to 50 tools. More than that, split into multiple scans.

**Q: Can I combine scans?**
A: Not yet - planned for future version. For now, arrange all tools together.

**Q: Does this work with non-tools?**
A: Yes! Crafting supplies, board game pieces, jewelry, electronics components, etc.

**Q: What if I don't have a LiDAR iPhone?**
A: Unfortunately, LiDAR is required for depth measurement. Non-Pro iPhones don't have this sensor.

---

## Checklist: Are You Ready?

Before your first scan, verify:

- [ ] iPhone has LiDAR sensor
- [ ] SnapTray app installed and trusted
- [ ] 4 fiducial markers created (ArUco + coins recommended)
- [ ] Black matte background (18" × 24" minimum)
- [ ] Good diffuse lighting (no harsh shadows)
- [ ] Tools cleaned and ready to arrange
- [ ] Enough space to hold phone 60-100cm above surface
- [ ] Slicer software installed (if 3D printing)
- [ ] Filament loaded in printer (if 3D printing)

**All checked?** You're ready to scan! 🎉

---

## Quick Reference Card

Print this and keep it by your scanning station:

```
┌─────────────────────────────────────────┐
│      SNAPTRAY QUICK REFERENCE           │
├─────────────────────────────────────────┤
│ CAMERA POSITION: 60-100cm above tools  │
│ LIGHTING: Diffuse overhead, no shadows │
│ BACKGROUND: Black matte                 │
│ TOOL SPACING: 10-20mm apart             │
│ FIDUCIALS: 4 corners, 150-250mm apart  │
│                                         │
│ BEST SETTINGS (PLA):                    │
│   XY Interference: -0.25mm              │
│   Tray Thickness: 12mm                  │
│   Edge Margin: 10mm                     │
│                                         │
│ PRINT SETTINGS (Ender 3):               │
│   Layer: 0.2mm                          │
│   Walls: 4                              │
│   Infill: 15%                           │
│   Temp: 205°C / 60°C                    │
│   Speed: 50mm/s (first layer 20mm/s)   │
│   Adhesion: Brim                        │
└─────────────────────────────────────────┘
```

---

**You're all set! Happy scanning! 🛠️**
