# SnapTray - LiDAR Tool Tray Generator

**Transform your tools into custom-fit 3D-printed trays in minutes using iPhone LiDAR**

SnapTray is a complete iOS app that captures tool layouts using LiDAR, automatically detects tool outlines, and generates ready-to-manufacture tray files for 3D printing or foam cutting.

![SnapTray Logo](docs/logo.png)

## Features

- **LiDAR Scanning**: Capture precise 3D depth data of your tools using iPhone Pro's LiDAR sensor
- **Fiducial Detection**: Automatic ArUco marker + coin detection for accurate scaling
- **Auto-Segmentation**: Intelligent tool outline detection with depth measurement
- **Smart Geometry**: Automatic offset, filleting, and finger notch generation
- **Multi-Format Export**:
  - **DXF** for foam cutting (laser/CNC)
  - **STL** for 3D printing (Ender 3, Prusa, etc.)
  - **PDF** with scale calibration template for verification
- **Material Presets**: Optimized for PLA, PETG, TPU, and foam with configurable tolerances
- **Print-Ready**: Generates calibration templates to verify scan accuracy

---

## Table of Contents

1. [Requirements](#requirements)
2. [Installation](#installation)
3. [Setup Guide](#setup-guide)
4. [Usage Instructions](#usage-instructions)
5. [Material Settings](#material-settings)
6. [Troubleshooting](#troubleshooting)
7. [File Formats](#file-formats)
8. [3D Printing Guide](#3d-printing-guide)

---

## Requirements

### Hardware
- **iPhone** with LiDAR sensor (iPhone 12 Pro or later, iPad Pro 2020 or later)
- **4 Fiducial markers** (see setup guide below)
- **Matte background** (black foam board recommended)
- **3D Printer** (optional): Ender 3 V3 Plus or similar FDM printer
- **Foam cutter** (optional): Laser cutter or CNC router

### Software
- iOS 15.0 or later
- Xcode 14.0+ (for building from source)

---

## Installation

### Option 1: Build from Source

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/SnapTray.git
   cd SnapTray
   ```

2. **Open in Xcode**:
   ```bash
   open SnapTrayApp.xcodeproj
   ```

3. **Configure signing**:
   - Select the `SnapTrayApp` target
   - Go to "Signing & Capabilities"
   - Select your development team
   - Xcode will automatically create a provisioning profile

4. **Connect your iPhone** and select it as the build target

5. **Build and run** (⌘R)

### Option 2: TestFlight (Coming Soon)
- Public beta link will be provided here

---

## Setup Guide

### 1. Create Fiducial Markers

You need 4 fiducial markers for accurate scale detection. SnapTray supports two methods:

#### Method A: ArUco Markers + Coins (Recommended)

1. **Print ArUco markers**:
   - Download from `docs/aruco_markers.pdf`
   - Print at 100% scale (no fit-to-page)
   - Each marker should be 50mm × 50mm
   - Cut out the 4 markers

2. **Attach to coins**:
   - Use 4 US quarters (24.26mm diameter)
   - Tape one ArUco marker to each coin
   - This provides both visual markers and physical scale reference

#### Method B: Coins Only (Backup)

- Use 4 US quarters placed at corners
- Less accurate than ArUco markers, but works

#### Method C: ArUco Markers Only

- Print 4 markers and use them directly
- Scale will be estimated from marker spacing

### 2. Prepare Scanning Surface

1. **Background**:
   - Use a **matte black** foam board (prevents reflections)
   - Size: At least 12" × 18" (30cm × 45cm)
   - Avoid glossy or reflective surfaces

2. **Lighting**:
   - Use **diffuse overhead lighting**
   - Avoid direct sunlight or harsh shadows
   - LED panel lights work great

3. **Workspace**:
   - Clear, flat surface
   - Good contrast between tools and background

### 3. Print the Scale Calibration Template

1. Open the app and create a test scan
2. Export the PDF report
3. Print the scale calibration page at **100% scale** (important!)
4. Verify with a ruler that the scale bars match real measurements
5. Adjust your printer settings if needed

---

## Usage Instructions

### Step 1: Arrange Your Tools

1. Place the matte background on a flat surface
2. Position the 4 fiducial markers at the **corners** of your desired tray area
   - Form a rectangle (doesn't need to be perfect)
   - Spacing: 150-300mm apart works well
3. Arrange your tools **flat** on the background
   - Leave 10-20mm spacing between tools
   - Ensure tools lie flat (not standing up)
   - Avoid overlapping

### Step 2: Capture with LiDAR

1. **Open SnapTray** and tap "Start New Scan"

2. **Position your iPhone**:
   - Hold **60-100cm (2-3 feet)** directly above the tools
   - Keep the phone **level** (parallel to surface)
   - Use both hands for stability

3. **Wait for plane detection**:
   - Green "Plane detected" indicator will appear
   - This typically takes 1-2 seconds

4. **Capture**:
   - Tap the camera button
   - Hold steady for 2-3 seconds during capture
   - The app will process the scan automatically

### Step 3: Review & Adjust

1. **Check detected tools**:
   - Each tool should have a colored outline
   - Verify tool count matches your layout

2. **Tap any tool** to adjust:
   - Add a label (e.g., "10mm wrench")
   - Override depth if needed
   - Adjust finger notch size/position
   - Disable tools you don't want

3. **Tray Settings** (gear icon):
   - Select material type
   - Adjust tray thickness (default 12mm)
   - Set edge margin (default 10mm)
   - Fine-tune XY interference for fit

### Step 4: Export Files

1. **Choose export format(s)**:
   - **DXF**: For foam cutting or 2D laser work
   - **STL**: For 3D printing
   - **PDF**: For documentation and scale verification

2. **Share files**:
   - Tap the share button on each file
   - AirDrop to Mac, save to Files, or email

3. **Verify scale** (important!):
   - Print the PDF report
   - Check that the scale bars match real measurements
   - If off, recalibrate and rescan

---

## Material Settings

### Interference (Fit) Explained

**Interference** = how much the pocket is offset from the tool outline

- **Negative values** = tighter fit (pocket smaller than tool)
- **Positive values** = looser fit (pocket larger than tool)
- **Zero** = exact fit (not recommended)

### Preset Values

| Material | XY Interference | Z Offset | Use Case |
|----------|----------------|----------|----------|
| **PLA (Snug)** | -0.25mm | 0mm | Secure hold, easy removal |
| **PLA (Loose)** | -0.15mm | +0.5mm | Easier insertion |
| **PETG (Snug)** | -0.30mm | 0mm | Slightly flexible |
| **PETG (Loose)** | -0.20mm | +0.5mm | Quick access |
| **TPU** | -0.40mm | 0mm | Grippy, shock-absorbing |
| **Foam (Laser)** | +0.30mm | 0mm | Accounts for compression |
| **Foam (CNC)** | +0.20mm | 0mm | Tighter foam fit |

### Custom Tuning

1. **Print a test coupon**:
   - Create a small scan with 2-3 tools
   - Export and print

2. **Test fit**:
   - Try inserting your tools
   - Too tight? Increase interference (more positive)
   - Too loose? Decrease interference (more negative)

3. **Save your settings**:
   - Adjust in the app
   - Rescan with new settings

---

## Troubleshooting

### Scan Issues

**Problem**: "Plane not detected"
- **Solution**: Ensure good lighting and the phone is level
- Move phone slightly up/down to help ARKit lock onto the surface

**Problem**: Tools not detected
- **Solution**:
  - Increase contrast (darker background)
  - Ensure tools are flat and not overlapping
  - Check lighting (avoid harsh shadows)

**Problem**: Fiducial markers not found
- **Solution**:
  - Print markers larger (60-70mm)
  - Ensure markers are visible and not obscured
  - Use coins as backup scale reference

**Problem**: Scale is wrong
- **Solution**:
  - Print the PDF calibration template
  - Measure with a ruler
  - If off by >5%, rescan with better fiducial placement
  - Ensure coins are actual US quarters (24.26mm)

### Export Issues

**Problem**: STL won't open in slicer
- **Solution**: Update your slicer software (Cura, PrusaSlicer)
- Try opening in a 3D viewer first (Windows 3D Viewer, Blender)

**Problem**: DXF has overlapping lines
- **Solution**: This is normal - the DXF includes multiple layers (original, simplified, offset)
- Use only the "POCKET" layer in your CAM software

**Problem**: PDF scale bars don't match ruler
- **Solution**:
  - Ensure you printed at 100% scale (no fit-to-page)
  - Check printer settings
  - Some printers have calibration offsets

### Print Quality Issues

**Problem**: Tools don't fit (too tight)
- **Solution**: Increase XY interference by +0.1mm increments

**Problem**: Tools are loose
- **Solution**: Decrease XY interference by -0.1mm increments

**Problem**: Rough pocket surfaces
- **Solution**:
  - Reduce layer height (0.15mm or 0.12mm)
  - Increase wall count to 4-5
  - Calibrate e-steps and flow rate

---

## File Formats

### DXF (Drawing Exchange Format)

**Use**: Foam cutting, laser cutting, CNC routing

**Layers**:
- `WORKSPACE`: Original scan area boundary
- `TRAY_OUTLINE`: Outer tray dimensions with margin
- `TOOL_X_POCKET`: Final pocket paths (use this for cutting)
- `TOOL_X_NOTCH`: Finger notch circles
- `TOOL_X_LABEL`: Text labels
- `TOOL_X_DEPTH`: Depth annotations

**Software Compatibility**:
- AutoCAD
- LibreCAD (free)
- Inkscape (free - import as DXF)
- Fusion 360
- SolidWorks

### STL (Stereolithography)

**Use**: 3D printing

**Format**: Binary STL

**Units**: Millimeters

**Software Compatibility**:
- Cura (Ender 3 recommended slicer)
- PrusaSlicer
- Simplify3D
- Bambu Studio

**Model Details**:
- Tray base with pockets subtracted
- Chamfered edges (optional)
- Drain holes (optional)
- Magnet cavities (optional)
- Embossed labels (optional)

### PDF Report

**Pages**:
1. **Overview**: Scan image, summary, workspace dimensions
2. **Measurements**: Table of all tools with dimensions and depths
3. **Scale Calibration**: Printable rulers and grid

**Use**:
- Print for reference while assembling trays
- Verify scan accuracy
- Documentation for shared projects

---

## 3D Printing Guide (Ender 3 V3 Plus)

### Recommended Settings

```
Material: PLA
Nozzle: 0.4mm
Layer Height: 0.2mm
First Layer: 0.24mm
Walls: 4
Infill: 15-20% (grid or gyroid)

Temperatures:
- Nozzle: 205-210°C
- Bed: 60°C

Speeds:
- First layer: 20mm/s
- Walls: 40mm/s
- Infill: 60mm/s

Bed Adhesion: Brim (for large trays)
```

### Slicing Tips

1. **Orientation**: Print flat (as exported)
2. **Support**: Not needed for standard trays
3. **Brim**: Add 5-8mm brim for trays larger than 150mm
4. **Warping prevention**:
   - Use blue tape or PEI sheet
   - Level bed carefully
   - Add mouse ears to corners for very large trays

### Material Alternatives

**PETG** (tougher):
```
Nozzle: 235-245°C
Bed: 80°C
Retraction: 5mm (reduce stringing)
```

**TPU** (grippy):
```
Nozzle: 220-230°C
Bed: 60°C
Print speed: 25mm/s (slow)
Flow: 95% (prevent over-extrusion)
```

### Post-Processing

1. **Deburring**: Remove brim/raft with hobby knife
2. **Sanding**: Light sand on edges (220 grit)
3. **Optional liner**: Cut thin EVA foam sheet for extra grip

---

## Advanced Features

### Tolerance Wizard (Future)

Create a test coupon with multiple interference values:
- Slots at -0.5, -0.4, -0.3, -0.2, -0.1, 0, +0.1, +0.2, +0.3, +0.4, +0.5mm
- Print and test fit to find your optimal value

### Multi-Drawer Projects

Save layouts for common drawer sizes:
- IKEA Alex (395 × 575mm)
- Harbor Freight tool cart
- Custom drawer dimensions

### Batch Processing

Scan multiple tool sets and export all at once

---

## FAQ

**Q: Do I need an iPhone Pro?**
A: Yes, LiDAR is only available on iPhone 12 Pro and later (Pro/Pro Max models), and iPad Pro 2020+

**Q: Can I use this for non-tool items?**
A: Absolutely! Works great for crafts, board game inserts, jewelry, parts organizers, etc.

**Q: What if I don't have a 3D printer?**
A: You can:
- Export DXF and have foam cut at a local shop
- Send STL to online 3D printing services (Shapeways, Craftcloud, etc.)
- Use the PDF as a template to cut foam by hand

**Q: How accurate is the depth measurement?**
A: LiDAR accuracy is ±2-5mm. The app uses median filtering to improve this to ~±1-2mm for most tools.

**Q: Can I edit the STL after export?**
A: Yes! Import into Fusion 360, Blender, or TinkerCAD to add custom features.

**Q: What's the maximum tray size?**
A: Limited by:
- Your 3D printer bed (Ender 3: 220×220mm)
- LiDAR range (optimal: 60-100cm distance = ~400×300mm scan area)
- For larger trays, split into multiple sections

---

## Project Structure

```
SnapTrayApp/
├── SnapTrayApp.swift           # Main app entry point
├── Models/
│   └── Project.swift           # Data models
├── Processors/
│   ├── LiDARCaptureManager.swift    # ARKit + LiDAR
│   ├── ArucoDetector.swift          # Fiducial detection
│   ├── SegmentationProcessor.swift  # Tool outline detection
│   └── GeometryProcessor.swift      # Offsets, fillets, notches
├── Exporters/
│   ├── DXFExporter.swift       # DXF generation
│   ├── STLExporter.swift       # STL generation
│   └── PDFExporter.swift       # PDF reports
└── Views/
    ├── ContentView.swift       # Main navigation
    ├── CaptureView.swift       # AR camera UI
    ├── ConfirmView.swift       # Tool review/edit
    └── ExportView.swift        # File export
```

---

## Contributing

Contributions welcome! Please:
1. Fork the repo
2. Create a feature branch
3. Submit a pull request

---

## License

MIT License - see [LICENSE](LICENSE) file

---

## Acknowledgments

- Apple ARKit & RealityKit for LiDAR APIs
- OpenCV community for fiducial detection algorithms
- 3D printing community for tolerance recommendations

---

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/SnapTray/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/SnapTray/discussions)
- **Email**: support@snaptray.app

---

## Roadmap

- [x] Core LiDAR scanning
- [x] DXF/STL/PDF export
- [x] Material presets
- [ ] Tolerance wizard with test coupons
- [ ] Multi-drawer project management
- [ ] Cloud sync for projects
- [ ] OCR for tool labels
- [ ] Auto-nesting for efficient layouts
- [ ] Share community tray designs
- [ ] Apple Watch remote trigger
- [ ] iPad support with Apple Pencil editing

---

**Made with ❤️ for makers, by makers**

*Stop wasting time searching for tools. Make a custom tray in minutes.*
