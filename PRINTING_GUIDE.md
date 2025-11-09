# 3D Printing Guide for SnapTray

Detailed guide for printing tool trays with optimal results on your 3D printer.

---

## Table of Contents

1. [Printer Compatibility](#printer-compatibility)
2. [Material Selection](#material-selection)
3. [Slicer Settings](#slicer-settings)
4. [Print Preparation](#print-preparation)
5. [Troubleshooting](#troubleshooting)
6. [Post-Processing](#post-processing)

---

## Printer Compatibility

### Tested Printers

SnapTray has been tested on:

- ✅ **Creality Ender 3 V3 Plus** (recommended)
- ✅ **Prusa i3 MK3S+**
- ✅ **Bambu Lab X1 Carbon**
- ✅ **Anycubic Kobra**
- ✅ **Elegoo Neptune 3**

Should work on any FDM printer with:
- Minimum bed size: 200mm × 200mm
- Heated bed capable of 60°C+
- 0.4mm nozzle (or 0.6mm for faster prints)

### Bed Size Considerations

| Printer Model | Bed Size | Max Tray Size |
|---------------|----------|---------------|
| Ender 3 V3 Plus | 220×220mm | 210×210mm |
| Ender 3 V2 | 220×220mm | 210×210mm |
| Prusa MK3S+ | 250×210mm | 240×200mm |
| Bambu X1 | 256×256mm | 246×246mm |
| CR-10 | 300×300mm | 290×290mm |

**For larger trays**: Split into multiple sections and glue together

---

## Material Selection

### PLA (Recommended for Beginners)

**Pros**:
- Easy to print
- Good dimensional accuracy
- Cheap
- Low warping
- Looks good

**Cons**:
- Brittle (can crack under heavy impact)
- Low heat resistance (softens >60°C)
- Less durable for heavy use

**Best for**:
- Home workshop drawers
- Light tools (screwdrivers, pliers)
- Desktop organization
- Craft supplies

**Settings**:
```
Nozzle Temp: 200-215°C
Bed Temp: 50-60°C
Print Speed: 50-60mm/s
Retraction: 5mm @ 45mm/s
```

**Recommended Brands**:
- eSun PLA+
- Prusament PLA
- Hatchbox PLA
- Overture PLA

### PETG (Recommended for Durability)

**Pros**:
- Much tougher than PLA
- Heat resistant to ~80°C
- Slightly flexible (absorbs impacts)
- Chemical resistant
- Food-safe options available

**Cons**:
- Stringing issues
- Harder to print (needs tuning)
- More expensive
- Can be messy

**Best for**:
- Mobile toolboxes (truck, work site)
- Heavy tools (wrenches, hammers)
- Outdoor use (garage, shed)
- High-use environments

**Settings**:
```
Nozzle Temp: 235-250°C
Bed Temp: 75-85°C
Print Speed: 40-50mm/s
Retraction: 3-4mm @ 30mm/s
Cooling: 30-50% (NOT full blast)
```

**Tips**:
- Dry filament before use (4hrs @ 65°C)
- Use glue stick on bed
- Enable Z-hop (0.4mm) to reduce stringing
- Tune retraction to minimize oozing

**Recommended Brands**:
- Prusament PETG
- eSun PETG
- Atomic Filament PETG

### TPU (Flexible - for Special Cases)

**Pros**:
- Very grippy (tools won't slide)
- Shock absorbent
- Quiet (tools don't rattle)
- Chemical resistant

**Cons**:
- SLOW to print (20-30mm/s max)
- Difficult to print (flexible)
- Stringing
- Expensive

**Best for**:
- Delicate tools (calipers, precision drivers)
- Anti-vibration (power tool boxes)
- Liner inserts (print TPU pockets, glue into PLA tray)

**Settings**:
```
Nozzle Temp: 220-235°C
Bed Temp: 50-60°C
Print Speed: 20-30mm/s
Retraction: 1-2mm @ 15mm/s (or disable)
Flow: 95%
```

**Tips**:
- Use direct drive extruder (Bowden is difficult)
- Slow everything down
- Increase wall count (6-8 walls)
- Consider hybrid: TPU liner + PLA tray

### ASA/ABS (Advanced)

**Pros**:
- Very tough
- Heat resistant (100°C+)
- UV resistant (won't yellow)
- Automotive-grade

**Cons**:
- Warping issues
- Requires enclosure
- Toxic fumes (need ventilation)
- Difficult to print

**Best for**:
- Outdoor use
- Vehicle toolboxes
- High-temperature environments

**Settings**:
```
Nozzle Temp: 240-260°C
Bed Temp: 95-110°C
Enclosure Temp: 40-50°C
Print Speed: 40-50mm/s
```

**Only use if**: You have an enclosed printer and experience with ABS

---

## Slicer Settings

### Recommended Slicer: Cura (Free)

Download: https://ultimaker.com/software/ultimaker-cura

### Profile: PLA Standard (Ender 3 V3 Plus)

```
QUALITY
├─ Layer Height: 0.20mm
├─ Initial Layer Height: 0.24mm
├─ Line Width: 0.4mm
└─ Wall Line Width: 0.42mm

SHELL
├─ Wall Thickness: 1.6mm (4 walls)
├─ Top/Bottom Thickness: 1.0mm (5 layers)
├─ Top/Bottom Pattern: Lines
└─ Outer Wall Wipe Distance: 0.2mm

INFILL
├─ Infill Density: 15%
├─ Infill Pattern: Grid (or Gyroid)
└─ Infill Overlap: 10%

MATERIAL
├─ Printing Temperature: 205°C
├─ Initial Layer Temp: 210°C
├─ Build Plate Temperature: 60°C
└─ Initial Layer Bed Temp: 65°C

SPEED
├─ Print Speed: 50mm/s
├─ Infill Speed: 60mm/s
├─ Wall Speed: 40mm/s
├─ Initial Layer Speed: 20mm/s
└─ Travel Speed: 150mm/s

TRAVEL
├─ Retraction Distance: 5mm
├─ Retraction Speed: 45mm/s
├─ Z Hop When Retracted: Enabled (0.4mm)
└─ Combing Mode: Within Infill

COOLING
├─ Enable Print Cooling: Yes
├─ Fan Speed: 100%
├─ Initial Fan Speed: 0%
└─ Regular Fan Speed at Layer: 3

BUILD PLATE ADHESION
├─ Build Plate Adhesion Type: Brim
├─ Brim Width: 5mm
└─ Brim Line Count: 5

SUPPORT
└─ Generate Support: No (not needed for trays)

SPECIAL MODES
├─ Print Sequence: All at Once
└─ Surface Mode: Normal
```

### Profile: PETG Durable (Ender 3 V3 Plus)

```
QUALITY
└─ Layer Height: 0.20mm

SHELL
└─ Wall Thickness: 1.6mm (4 walls)

INFILL
├─ Infill Density: 20%
└─ Infill Pattern: Gyroid

MATERIAL
├─ Printing Temperature: 240°C
├─ Build Plate Temperature: 80°C
└─ Filament Diameter: 1.75mm

SPEED
├─ Print Speed: 45mm/s
├─ Initial Layer Speed: 18mm/s
└─ Retraction Distance: 3.5mm

COOLING
├─ Fan Speed: 40%
└─ Initial Fan Speed: 0%

BUILD PLATE ADHESION
└─ Adhesion Type: Brim (8mm)
```

### Profile: High Quality (Slower, Better Finish)

Use for presentation pieces or very precise fits:

```
Layer Height: 0.12mm
Walls: 5
Infill: 20% Gyroid
Speed: 35mm/s
Initial Layer: 15mm/s
```

**Print time**: ~2-3× longer, but excellent surface finish

---

## Print Preparation

### Before You Print

1. **Level your bed**:
   - Paper test on all 4 corners + center
   - Use mesh bed leveling if available
   - Re-level every 10-20 prints

2. **Clean the bed**:
   - Isopropyl alcohol (IPA) on glass/PEI
   - Dish soap + water for textured beds
   - Dry completely

3. **Check filament**:
   - Not tangled on spool
   - Dry (not brittle or hissing)
   - Enough remaining for print

4. **Preheat bed**:
   - Let bed heat for 5 minutes before printing
   - Ensures even temperature

### Slicing Your Tray

1. **Import STL** into Cura

2. **Check orientation**:
   - Tray should be flat on bed (bottom down)
   - NO supports needed

3. **Position**:
   - Center of bed
   - If multiple trays, space 10mm apart

4. **Apply profile**:
   - Select "PLA Standard" (or your custom profile)

5. **Preview layers**:
   - Check for:
     - No supports (should be none)
     - Good first layer coverage
     - Pockets look correct

6. **Estimate time**:
   - Typical tray: 2-5 hours depending on size
   - Large drawer tray: 6-10 hours

7. **Slice** and save G-code

### Transfer to Printer

**SD Card** (most reliable):
- Save G-code to SD card
- Eject safely
- Insert into printer

**OctoPrint/Network** (convenient):
- Upload G-code via web interface
- Start print remotely

**Direct USB** (not recommended):
- Computer must stay connected entire print
- Risk of disconnection

---

## During the Print

### First Layer Critical!

**Watch the first 2-3 layers closely**:

✅ **Good first layer**:
- Filament squished slightly into bed
- No gaps between lines
- Smooth, even surface
- Corners stick well

❌ **Bad first layer**:
- Lines not touching each other (too high)
- Filament squished flat (too low)
- Corners lifting
- Uneven surface

**If first layer fails**:
1. Stop print immediately (don't waste filament)
2. Re-level bed
3. Clean bed again
4. Adjust Z-offset
5. Restart

### Mid-Print Monitoring

**Check every hour or so**:
- Filament still feeding
- No spaghetti (layer shift)
- Bed still stuck
- Temperature stable

**Don't**:
- Open enclosure mid-print (causes warping)
- Move printer
- Adjust settings (unless emergency)

### Estimated Times

| Tray Size | Infill | Layer | Time |
|-----------|--------|-------|------|
| 100×100mm | 15% | 0.2mm | ~2hrs |
| 150×150mm | 15% | 0.2mm | ~4hrs |
| 200×200mm | 15% | 0.2mm | ~7hrs |
| 200×200mm | 20% | 0.15mm | ~12hrs |

---

## Print Issues & Fixes

### Warping (Corners Lifting)

**Cause**: Uneven cooling, poor adhesion

**Fixes**:
1. Increase bed temp (+5°C)
2. Use larger brim (8-10mm)
3. Add "mouse ears" to corners (in slicer)
4. Close windows/doors (prevent drafts)
5. Use glue stick or hairspray on bed
6. Lower cooling fan to 75%

### Stringing (Hairy Surface)

**Cause**: Oozing during travel moves

**Fixes**:
1. Increase retraction distance (+0.5mm)
2. Decrease temperature (-5°C)
3. Increase retraction speed (+10mm/s)
4. Enable Z-hop (0.4mm)
5. Dry filament (moisture causes stringing)

### Layer Shifting

**Cause**: Belt skipping, mechanical issue

**Fixes**:
1. Tighten belts (should "twang" when plucked)
2. Slow down print speed
3. Check wheels aren't too tight/loose
4. Lubricate linear rods
5. Check for debris on rails

### Under-Extrusion (Gaps in Print)

**Cause**: Not enough filament

**Fixes**:
1. Increase flow rate (+2-5%)
2. Check for nozzle clog
3. Calibrate e-steps
4. Increase temperature (+5°C)
5. Check filament diameter (should be 1.75mm ±0.05mm)

### Poor Pocket Quality

**Cause**: Low resolution or poor cooling

**Fixes**:
1. Reduce layer height (0.2 → 0.15mm)
2. Increase wall count (4 → 5)
3. Slow down (50 → 40mm/s)
4. Increase cooling (100% fan)
5. Check nozzle isn't worn

---

## Post-Processing

### Removing from Bed

1. **Let cool** to room temperature (10-15 min)
   - Tray will release easier when cold
   - Less likely to warp

2. **Remove carefully**:
   - Use spatula/scraper at shallow angle
   - Start at a corner
   - Work your way around
   - Don't bend excessively

### Removing Brim/Raft

1. **Hobby knife** for precise removal
2. **Flush cutters** for thicker brims
3. **Sand lightly** (220 grit) to smooth edges

### Cleaning Up

1. **Inspect pockets**:
   - Remove any stringing
   - Check for blobs or zits
   - Clean with knife if needed

2. **Deburr edges**:
   - Light sand on sharp corners
   - 220 grit sandpaper
   - Or use a deburring tool

3. **Test fit tools**:
   - Should slide in with light pressure
   - Should stay in when tilted 45°

### Optional Finishing

**Sanding**:
- 220 → 400 → 800 grit for smooth finish
- Wet sand to prevent clogging

**Painting**:
- Prime with filler primer
- Spray paint (multiple thin coats)
- Clear coat for durability

**Lining**:
- Cut thin EVA foam to fit pockets
- Glue in place for extra grip
- Use TPU for best results

**Labeling**:
- Emboss during print (enable in SnapTray settings)
- Or use label maker
- Or paint with acrylic paint pen

---

## Advanced Techniques

### Multi-Material Printing

Print base and walls in different materials:

1. **Base**: PLA (rigid, cheap)
2. **Pockets**: TPU (grippy)

**Process**:
- Slice with material change at pocket layer
- Pause print, swap filament
- Or use multi-material system (MMU, AMS)

### Magnet Retention

Add magnets to hold tools in place:

1. **Enable "Magnet Cavities"** in SnapTray settings
2. Print tray
3. **Glue in 6mm × 2mm neodymium magnets**:
   - Use CA glue (super glue)
   - Ensure polarity is correct (test first!)
   - Let cure 24 hours

**Best for**:
- Mobile toolboxes
- Vertical storage
- Vibration environments

### Drain Holes

For outdoor/wet environments:

1. **Enable "Drain Holes"** in SnapTray settings
2. Holes will be placed at pocket bottoms
3. Prevents water accumulation

### Color Changes

Add visual interest or organization:

1. **Manual color change**:
   - Slice and note layer number
   - Add "Pause at Layer" script
   - Swap filament during print

2. **By tool type**:
   - Layer 1-10: Base (black)
   - Layer 11-20: Sockets pocket (red)
   - Layer 21-30: Wrenches pocket (blue)

---

## Calibration for Perfect Fit

### E-Steps Calibration

Ensures accurate filament flow:

1. Mark filament 120mm from extruder
2. Extrude 100mm
3. Measure remaining distance
4. Calculate: new_steps = old_steps × (100 / actual_extruded)
5. Save to firmware

### Flow Rate Calibration

Fine-tunes extrusion multiplier:

1. Print single-wall cube
2. Measure wall thickness with calipers
3. Should be exactly 0.4mm (for 0.4mm nozzle)
4. Adjust flow: new_flow = old_flow × (0.4 / measured)

### Temperature Tower

Find optimal temperature:

1. Download temp tower STL
2. Slice with temp changes every 5°C
3. Print and examine quality
4. Use temperature with:
   - Best overhangs
   - Minimal stringing
   - Good layer adhesion

### Tolerance Test

Print a fit test piece:

1. In SnapTray, scan a single tool multiple times
2. Export with interference values: -0.5, -0.4, -0.3, -0.2, -0.1, 0, +0.1
3. Print all pockets in one tray
4. Test fit your tool in each
5. Note which fits best
6. Use that interference for future prints

---

## Material Storage

**Keep filament dry**:
- Store in sealed bags/containers
- Add desiccant packets (silica gel)
- Use dry boxes for active spools
- Dry filament if it's been sitting:
  - PLA: 4-6 hours @ 50°C
  - PETG: 6-8 hours @ 65°C
  - TPU: 4-6 hours @ 60°C

**Signs of wet filament**:
- Hissing/popping sounds during print
- Excessive stringing
- Brittle prints
- Rough surface finish

---

## Cost Estimates

### Material Cost Per Tray

| Tray Size | Weight | PLA Cost | PETG Cost |
|-----------|--------|----------|-----------|
| Small (100×100mm) | ~50g | $1.00 | $1.50 |
| Medium (150×150mm) | ~120g | $2.40 | $3.60 |
| Large (200×200mm) | ~250g | $5.00 | $7.50 |

*Based on $20/kg PLA, $30/kg PETG*

### Time vs. Quality

| Setting | Print Time | Quality | Cost |
|---------|------------|---------|------|
| **Draft** (0.28mm, 15%) | 100% | Fair | $ |
| **Standard** (0.20mm, 15%) | 150% | Good | $$ |
| **Quality** (0.15mm, 20%) | 225% | Great | $$$ |
| **Fine** (0.12mm, 25%) | 350% | Excellent | $$$$ |

---

## Quick Reference

### Pre-Flight Checklist

- [ ] Bed leveled (paper test)
- [ ] Bed cleaned (IPA wipe)
- [ ] Filament loaded and dry
- [ ] Nozzle clean (no old filament)
- [ ] SD card inserted or network connected
- [ ] First layer settings double-checked
- [ ] Brim enabled for large trays
- [ ] Estimated time reasonable

### First Layer Checklist

- [ ] Lines stick to bed
- [ ] No gaps between lines
- [ ] Corners not lifting
- [ ] Extrusion looks consistent
- [ ] Bed temperature stable

### Post-Print Checklist

- [ ] Tray cooled to room temp
- [ ] Removed from bed without damage
- [ ] Brim removed cleanly
- [ ] Pockets free of strings/blobs
- [ ] Edges deburred
- [ ] Tools fit correctly

---

**Happy printing! 🖨️**
