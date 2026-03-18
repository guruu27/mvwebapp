# Frontend Redesign Plan: Dark Mode + Green/Yellow + 3-Level Collapsible Accordion

## Overview

**Three-degree clustered view:**
```
Level 1: Processing Station  (root accordion)
  Level 2: Material          (nested accordion inside station)
    Level 3: Sheet #         (nested accordion inside material)
      → Parts Table          (flat table inside sheet)
```

Each level is collapsed by default showing a summary row with aggregated metrics.
Click to expand reveals the next level down.

---

## PHASE 1: Dark Mode + Green/Yellow Color Scheme (CSS)

**File: `styles.css`**

### Step 1.1 — Replace CSS Variables (`:root`)

| Current | New | Purpose |
|---------|-----|---------|
| `--primary-color: #2563eb` (blue) | `#22c55e` (green) | Primary accent |
| `--secondary-color: #7c3aed` (purple) | `#eab308` (yellow) | Secondary accent |
| `--success-color: #10b981` | `#4ade80` (light green) | Success states |
| `--warning-color: #f59e0b` | `#facc15` (bright yellow) | Warning states |
| `--danger-color: #ef4444` | `#ef4444` (keep red) | Error states |
| `--dark: #1e293b` | `#0a0a0a` (true dark) | Dark base |
| `--light: #f8fafc` | `#1a1a2e` (dark surface) | Surface color |
| `--border: #e2e8f0` | `#2d2d44` (dark border) | Borders |

**New variables to add:**
```css
--bg-primary: #0f0f1a;              /* page background */
--bg-surface: #1a1a2e;              /* cards, containers */
--bg-surface-hover: #252540;        /* card hover */
--bg-level-1: #1a1a2e;             /* station level bg */
--bg-level-2: #151525;             /* material level bg */
--bg-level-3: #111120;             /* sheet level bg */
--bg-level-4: #0d0d1a;             /* parts table bg */
--text-primary: #e2e8f0;            /* main text - light gray */
--text-secondary: #94a3b8;          /* subdued text */
--accent-green: #22c55e;            /* primary accent - stations */
--accent-yellow: #eab308;           /* secondary accent - materials */
--accent-cyan: #06b6d4;             /* tertiary accent - sheets */
--accent-green-dim: rgba(34,197,94,0.15);
--accent-yellow-dim: rgba(234,179,8,0.15);
--accent-cyan-dim: rgba(6,182,212,0.15);
```

**Color coding per level:**
| Level | Element | Accent Color | Meaning |
|-------|---------|-------------|---------|
| 1 | Processing Station | Green `#22c55e` | Root level |
| 2 | Material | Yellow `#eab308` | Material grouping |
| 3 | Sheet # | Cyan `#06b6d4` | Individual sheets |
| — | Metric values | Yellow `#eab308` | All numbers/values |

### Step 1.2 — Body & Container
- `body` background: `#0f0f1a` solid dark, remove purple/blue gradient
- `color: var(--text-primary)`

### Step 1.3 — Header
- Background: `var(--bg-surface)`
- Title: `var(--accent-green)`
- Subtitle: `var(--text-secondary)`
- Bottom border: `1px solid var(--accent-green)` with subtle glow

### Step 1.4 — Cards (Project + Work Order)
- Background: `var(--bg-surface)`
- Border: `1px solid var(--border)`
- Hover: border → `var(--accent-green)`, box-shadow → green glow
- `.project-number` / `.wo-number`: `var(--accent-yellow)`
- `.project-name` / `.wo-name`: `var(--text-primary)`
- `.stat-value`: `var(--accent-green)`

### Step 1.5 — Summary Cards
Dark background with colored left border per type:
- `.summary-card.nesting`: left-border green
- `.summary-card.panel`: left-border yellow
- `.summary-card.edge`: left-border cyan
- `.summary-card.operations`: left-border `#f97316` (orange)
- `.summary-card.totals`: left-border `#8b5cf6` (purple)

### Step 1.6 — Modals
- Backdrop: `rgba(0,0,0,0.7)`
- Content: `var(--bg-surface)`, border `var(--border)`
- Inputs: bg `#0f0f1a`, green focus border

### Step 1.7 — Breadcrumb, Buttons, Loading
- Back button: green outlined, hover → green filled
- Spinner: green border-top-color

---

## PHASE 2: Three-Level Accordion — Data Model & Aggregation

### Step 2.1 — Data Hierarchy (from backend response)

The backend already returns this hierarchy:
```
data.processing_stations[]
  └── station.materials[]
        └── material.sheets[]
              └── sheet.parts[]
```

Each level's summary row needs **aggregated metrics** computed from all descendants.

### Step 2.2 — Aggregation Functions

**Sheet-level aggregates** (sum across parts within one sheet):
```javascript
function computeSheetAggregates(sheet) {
    const parts = sheet.parts || [];
    return {
        partCount:     parts.length,
        totalToolpath: parts.reduce((s, p) => s + (p.toolpath_m || 0), 0),
        totalHDrills:  parts.reduce((s, p) => s + (p.h_drills || 0), 0),
        totalVDrills:  parts.reduce((s, p) => s + (p.v_drills || 0), 0),
        totalEdgeband: parts.reduce((s, p) => s + (p.edgeband_m || 0), 0),
        totalMiters:   parts.filter(p => p.is_miter).length,
        totalP2P:      parts.filter(p => p.is_p2p).length,
        totalArea:     parts.reduce((s, p) => s + (p.area_sqm || 0), 0),
    };
}
```

**Material-level aggregates** (sum across all sheets within one material):
```javascript
function computeMaterialAggregates(material) {
    let totalSheets = 0, totalParts = 0, totalToolpath = 0;
    let totalHDrills = 0, totalVDrills = 0, totalEdgeband = 0;
    let totalMiters = 0, totalP2P = 0, totalArea = 0;

    (material.sheets || []).forEach(sheet => {
        totalSheets++;
        (sheet.parts || []).forEach(part => {
            totalParts++;
            totalToolpath += part.toolpath_m || 0;
            totalHDrills  += part.h_drills || 0;
            totalVDrills  += part.v_drills || 0;
            totalEdgeband += part.edgeband_m || 0;
            totalArea     += part.area_sqm || 0;
            if (part.is_miter) totalMiters++;
            if (part.is_p2p) totalP2P++;
        });
    });

    return { totalSheets, totalParts, totalToolpath, totalHDrills,
             totalVDrills, totalEdgeband, totalMiters, totalP2P, totalArea };
}
```

**Station-level aggregates** (sum across all materials within one station):
```javascript
function computeStationAggregates(station) {
    let totalMaterials = 0, totalSheets = 0, totalParts = 0, totalToolpath = 0;
    let totalHDrills = 0, totalVDrills = 0, totalEdgeband = 0;
    let totalMiters = 0, totalP2P = 0, totalArea = 0;

    (station.materials || []).forEach(mat => {
        totalMaterials++;
        (mat.sheets || []).forEach(sheet => {
            totalSheets++;
            (sheet.parts || []).forEach(part => {
                totalParts++;
                totalToolpath += part.toolpath_m || 0;
                totalHDrills  += part.h_drills || 0;
                totalVDrills  += part.v_drills || 0;
                totalEdgeband += part.edgeband_m || 0;
                totalArea     += part.area_sqm || 0;
                if (part.is_miter) totalMiters++;
                if (part.is_p2p) totalP2P++;
            });
        });
    });

    return { totalMaterials, totalSheets, totalParts, totalToolpath, totalHDrills,
             totalVDrills, totalEdgeband, totalMiters, totalP2P, totalArea };
}
```

---

## PHASE 3: Three-Level Accordion — Visual Layout

### Collapsed Default View (what user sees first)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  [CNC]  [SAW]  [EB]  [OPS]  [TOTALS]           ← Summary Cards                    │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─ LEVEL 1 ───────────────────────────────────────────────────────────────────────────┐
│ ▶ CNC Nesting     3 materials │ 5 sheets │ 42 parts │ 12.5m TP │ 6.2m EB │ 3 mit  │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ ▶ Panel Saw       2 materials │ 3 sheets │ 18 parts │  0m TP   │  0m EB  │ 0 mit  │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### After clicking "CNC Nesting" (Level 1 expanded → shows Level 2)

```
┌─ LEVEL 1 ───────────────────────────────────────────────────────────────────────────┐
│ ▼ CNC Nesting     3 materials │ 5 sheets │ 42 parts │ 12.5m TP │ 6.2m EB │ 3 mit  │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  ┌─ LEVEL 2 ────────────────────────────────────────────────────────────────────┐   │
│  │ ▶ 3/4 Melamine White    3 sheets │ 28 parts │ 8.2m TP │ 4.1m EB │ 2 mit    │   │
│  ├──────────────────────────────────────────────────────────────────────────────┤   │
│  │ ▶ 1/2 MDF               1 sheet  │  8 parts │ 2.1m TP │ 1.0m EB │ 1 mit    │   │
│  ├──────────────────────────────────────────────────────────────────────────────┤   │
│  │ ▶ 1/4 Hardboard          1 sheet  │  6 parts │ 2.2m TP │ 1.1m EB │ 0 mit    │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ ▶ Panel Saw       2 materials │ 3 sheets │ 18 parts │  0m TP   │  0m EB  │ 0 mit  │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### After clicking "3/4 Melamine White" (Level 2 expanded → shows Level 3)

```
│  ┌─ LEVEL 2 ────────────────────────────────────────────────────────────────────┐   │
│  │ ▼ 3/4 Melamine White    3 sheets │ 28 parts │ 8.2m TP │ 4.1m EB │ 2 mit    │   │
│  ├──────────────────────────────────────────────────────────────────────────────┤   │
│  │  ┌─ LEVEL 3 ─────────────────────────────────────────────────────────────┐  │   │
│  │  │ ▶ Sheet #1  2440x1220  │ 10 parts │ 3.4m TP │ 12 HD │ 4 VD │ 1.2m EB│  │   │
│  │  ├────────────────────────────────────────────────────────────────────────┤  │   │
│  │  │ ▶ Sheet #2  2440x1220  │ 12 parts │ 3.0m TP │ 8 HD  │ 2 VD │ 1.8m EB│  │   │
│  │  ├────────────────────────────────────────────────────────────────────────┤  │   │
│  │  │ ▶ Sheet #3  2440x1220  │  6 parts │ 1.8m TP │ 4 HD  │ 2 VD │ 1.1m EB│  │   │
│  │  └────────────────────────────────────────────────────────────────────────┘  │   │
│  ├──────────────────────────────────────────────────────────────────────────────┤   │
│  │ ▶ 1/2 MDF               1 sheet  │  8 parts │ 2.1m TP │ 1.0m EB │ 1 mit    │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
```

### After clicking "Sheet #1" (Level 3 expanded → shows Parts Table)

```
│  │  ┌─ LEVEL 3 ─────────────────────────────────────────────────────────────┐  │   │
│  │  │ ▼ Sheet #1  2440x1220  │ 10 parts │ 3.4m TP │ 12 HD │ 4 VD │ 1.2m EB│  │   │
│  │  ├────────────────────────────────────────────────────────────────────────┤  │   │
│  │  │  ┌─ PARTS TABLE ──────────────────────────────────────────────────┐   │  │   │
│  │  │  │ Part Name        │ Size     │ Area   │ TP   │HD│VD│ EB  │Prod │   │  │   │
│  │  │  ├──────────────────┼──────────┼────────┼──────┼──┼──┼─────┼─────│   │  │   │
│  │  │  │ Left Side [P2P]  │ 762x584  │ 0.4451 │ 0.85 │ 4│ 2│ 0.52│Bs x2│   │  │   │
│  │  │  │ Right Side [P2P] │ 762x584  │ 0.4451 │ 0.85 │ 4│ 2│ 0.52│Bs x2│   │  │   │
│  │  │  │ Bottom [@Miter]  │ 584x508  │ 0.2967 │ 0.45 │ 2│ 0│ 0.38│Bs x2│   │  │   │
│  │  │  │ Top Panel        │ 584x508  │ 0.2967 │ 0.45 │ 2│ 0│ 0.38│Bs x2│   │  │   │
│  │  │  │ Shelf            │ 559x483  │ 0.2700 │ 0.40 │ 0│ 0│ 0.30│Bs x2│   │  │   │
│  │  │  │ ...              │          │        │      │  │  │     │     │   │  │   │
│  │  │  └─────────────────────────────────────────────────────────────────┘   │  │   │
│  │  ├────────────────────────────────────────────────────────────────────────┤  │   │
│  │  │ ▶ Sheet #2  2440x1220  │ 12 parts │ 3.0m TP │ 8 HD  │ 2 VD │ 1.8m EB│  │   │
│  │  └────────────────────────────────────────────────────────────────────────┘  │   │
```

---

## PHASE 4: Summary Row Metrics Per Level

### Level 1 — Station Summary Row

| Metric | Label | Computation |
|--------|-------|-------------|
| Materials | "3 materials" | Count of `station.materials[]` |
| Sheets | "5 sheets" | Count all sheets across all materials |
| Parts | "42 parts" | Count all parts across all materials/sheets |
| Toolpath | "12.5m TP" | Sum all `part.toolpath_m` |
| Edgeband | "6.2m EB" | Sum all `part.edgeband_m` |
| Miter | "3 mit" | Count parts where `is_miter` |

### Level 2 — Material Summary Row

| Metric | Label | Computation |
|--------|-------|-------------|
| Sheets | "3 sheets" | Count of `material.sheets[]` |
| Parts | "28 parts" | Count all parts across all sheets |
| Toolpath | "8.2m TP" | Sum all `part.toolpath_m` for this material |
| Edgeband | "4.1m EB" | Sum all `part.edgeband_m` for this material |
| Miter | "2 mit" | Count parts where `is_miter` for this material |

### Level 3 — Sheet Summary Row

| Metric | Label | Computation |
|--------|-------|-------------|
| Sheet Size | "2440x1220" | From `sheet.length_mm x sheet.width_mm` |
| Parts | "10 parts" | `sheet.parts.length` |
| Toolpath | "3.4m TP" | Sum `part.toolpath_m` for this sheet |
| H.Drill | "12 HD" | Sum `part.h_drills` for this sheet |
| V.Drill | "4 VD" | Sum `part.v_drills` for this sheet |
| Edgeband | "1.2m EB" | Sum `part.edgeband_m` for this sheet |
| Miter | "1 mit" | Count `is_miter` parts for this sheet |
| P2P | "2 P2P" | Count `is_p2p` parts for this sheet |

### Level 4 — Parts Table Columns

| Column | Source | Format |
|--------|--------|--------|
| Part Name | `part.name` | + [P2P] badge + [Miter] badge |
| Size (mm) | `part.length_mm x part.width_mm` | Integer dimensions |
| Area (m²) | `part.area_sqm` | 4 decimal places |
| ToolPath (m) | `part.toolpath_m` | 2 decimal places |
| H.Drill | `part.h_drills` | Integer or "-" |
| V.Drill | `part.v_drills` | Integer or "-" |
| Edge (m) | `part.edgeband_m` | 2 decimal places |
| Product | `part.product_name (x{qty})` | Name + quantity badge |

---

## PHASE 5: Complete HTML Structure

```html
<!-- Summary Cards (always visible) -->
<div class="summary-bar">
    <div class="summary-card nesting">...</div>
    <div class="summary-card panel">...</div>
    <div class="summary-card edge">...</div>
    <div class="summary-card operations">...</div>
    <div class="summary-card totals">...</div>
</div>

<!-- ============ LEVEL 1: Station Accordion ============ -->
<div class="accordion level-1">

    <!-- Station Header (always visible, GREEN accent) -->
    <div class="accordion-header level-1-header" onclick="toggleAccordion('s0')">
        <span class="expand-icon" id="s0-icon">▶</span>
        <span class="accordion-title level-1-title">CNC Nesting</span>
        <div class="accordion-metrics">
            <span><strong>3</strong> materials</span>
            <span><strong>5</strong> sheets</span>
            <span><strong>42</strong> parts</span>
            <span><strong>12.5</strong>m TP</span>
            <span><strong>6.2</strong>m EB</span>
            <span><strong>3</strong> mit</span>
        </div>
    </div>

    <!-- Station Body (hidden) -->
    <div id="s0-body" class="accordion-body" style="display:none;">

        <!-- ============ LEVEL 2: Material Accordion ============ -->
        <div class="accordion level-2">

            <!-- Material Header (YELLOW accent) -->
            <div class="accordion-header level-2-header" onclick="toggleAccordion('s0-m0')">
                <span class="expand-icon" id="s0-m0-icon">▶</span>
                <span class="accordion-title level-2-title">3/4 Melamine White</span>
                <div class="accordion-metrics">
                    <span><strong>3</strong> sheets</span>
                    <span><strong>28</strong> parts</span>
                    <span><strong>8.2</strong>m TP</span>
                    <span><strong>4.1</strong>m EB</span>
                    <span><strong>2</strong> mit</span>
                </div>
            </div>

            <!-- Material Body (hidden) -->
            <div id="s0-m0-body" class="accordion-body" style="display:none;">

                <!-- ============ LEVEL 3: Sheet Accordion ============ -->
                <div class="accordion level-3">

                    <!-- Sheet Header (CYAN accent) -->
                    <div class="accordion-header level-3-header" onclick="toggleAccordion('s0-m0-sh0')">
                        <span class="expand-icon" id="s0-m0-sh0-icon">▶</span>
                        <span class="accordion-title level-3-title">Sheet #1</span>
                        <span class="sheet-size">2440 x 1220</span>
                        <div class="accordion-metrics">
                            <span><strong>10</strong> parts</span>
                            <span><strong>3.4</strong>m TP</span>
                            <span><strong>12</strong> HD</span>
                            <span><strong>4</strong> VD</span>
                            <span><strong>1.2</strong>m EB</span>
                            <span><strong>1</strong> mit</span>
                            <span><strong>2</strong> P2P</span>
                        </div>
                    </div>

                    <!-- Sheet Body - Parts Table (hidden) -->
                    <div id="s0-m0-sh0-body" class="accordion-body" style="display:none;">
                        <table class="parts-table">
                            <thead>
                                <tr>
                                    <th>Part Name</th>
                                    <th>Size (mm)</th>
                                    <th>Area (m²)</th>
                                    <th>ToolPath (m)</th>
                                    <th>H.Drill</th>
                                    <th>V.Drill</th>
                                    <th>Edge (m)</th>
                                    <th>Product</th>
                                </tr>
                            </thead>
                            <tbody>
                                <tr>
                                    <td>Left Side <span class="badge p2p">P2P</span></td>
                                    <td>762 x 584</td>
                                    <td>0.4451</td>
                                    <td>0.85</td>
                                    <td>4</td>
                                    <td>2</td>
                                    <td>0.52</td>
                                    <td>Base Cabinet <span class="product-qty">(x2)</span></td>
                                </tr>
                                <!-- ... more parts ... -->
                            </tbody>
                        </table>
                    </div>

                </div><!-- /level-3 sheet accordion -->

                <!-- More sheet accordions... -->

            </div><!-- /level-2 material body -->

        </div><!-- /level-2 material accordion -->

        <!-- More material accordions... -->

    </div><!-- /level-1 station body -->

</div><!-- /level-1 station accordion -->

<!-- More station accordions... -->
```

---

## PHASE 6: JavaScript Implementation

### Step 6.1 — Universal Toggle Function

One function handles all three levels. Uses the ID naming convention:
- Station: `s0`, `s1`, ...
- Material: `s0-m0`, `s0-m1`, ...
- Sheet: `s0-m0-sh0`, `s0-m0-sh1`, ...

```javascript
function toggleAccordion(id) {
    const body = document.getElementById(id + '-body');
    const icon = document.getElementById(id + '-icon');
    const header = icon.closest('.accordion-header');

    if (body.style.display === 'none') {
        body.style.display = 'block';
        icon.textContent = '▼';
        header.classList.add('expanded');
    } else {
        body.style.display = 'none';
        icon.textContent = '▶';
        header.classList.remove('expanded');
    }
}
```

### Step 6.2 — Rewrite `displayWorkOrderProcessing()`

```javascript
function displayWorkOrderProcessing(data) {
    const container = document.getElementById('processing-tree');
    container.innerHTML = '';

    if (!data.processing_stations || data.processing_stations.length === 0) {
        container.innerHTML = '<p class="no-data">No processing data available</p>';
        return;
    }

    const s = data.summary || {};

    // ---- SUMMARY CARDS (same as current) ----
    let html = `<div class="summary-bar">
        <!-- ... 5 summary cards unchanged ... -->
    </div>`;

    // ---- LEVEL 1: STATION ACCORDIONS ----
    data.processing_stations.forEach((station, si) => {
        const sa = computeStationAggregates(station);

        html += `
        <div class="accordion level-1">
            <div class="accordion-header level-1-header" onclick="toggleAccordion('s${si}')">
                <span class="expand-icon" id="s${si}-icon">▶</span>
                <span class="accordion-title level-1-title">${station.station_name}</span>
                <div class="accordion-metrics">
                    <span><strong>${sa.totalMaterials}</strong> materials</span>
                    <span><strong>${sa.totalSheets}</strong> sheets</span>
                    <span><strong>${sa.totalParts}</strong> parts</span>
                    <span><strong>${sa.totalToolpath.toFixed(1)}</strong>m TP</span>
                    <span><strong>${sa.totalEdgeband.toFixed(1)}</strong>m EB</span>
                    <span><strong>${sa.totalMiters}</strong> mit</span>
                </div>
            </div>
            <div id="s${si}-body" class="accordion-body" style="display:none;">
        `;

        // ---- LEVEL 2: MATERIAL ACCORDIONS ----
        (station.materials || []).forEach((material, mi) => {
            const ma = computeMaterialAggregates(material);

            html += `
            <div class="accordion level-2">
                <div class="accordion-header level-2-header" onclick="toggleAccordion('s${si}-m${mi}')">
                    <span class="expand-icon" id="s${si}-m${mi}-icon">▶</span>
                    <span class="accordion-title level-2-title">${material.material_name}</span>
                    <div class="accordion-metrics">
                        <span><strong>${ma.totalSheets}</strong> sheets</span>
                        <span><strong>${ma.totalParts}</strong> parts</span>
                        <span><strong>${ma.totalToolpath.toFixed(1)}</strong>m TP</span>
                        <span><strong>${ma.totalEdgeband.toFixed(1)}</strong>m EB</span>
                        <span><strong>${ma.totalMiters}</strong> mit</span>
                    </div>
                </div>
                <div id="s${si}-m${mi}-body" class="accordion-body" style="display:none;">
            `;

            // ---- LEVEL 3: SHEET ACCORDIONS ----
            (material.sheets || []).forEach((sheet, shi) => {
                const sha = computeSheetAggregates(sheet);
                const sheetId = `s${si}-m${mi}-sh${shi}`;

                html += `
                <div class="accordion level-3">
                    <div class="accordion-header level-3-header" onclick="toggleAccordion('${sheetId}')">
                        <span class="expand-icon" id="${sheetId}-icon">▶</span>
                        <span class="accordion-title level-3-title">Sheet #${sheet.sheet_number}</span>
                        <span class="sheet-size">${sheet.length_mm} x ${sheet.width_mm}</span>
                        <div class="accordion-metrics">
                            <span><strong>${sha.partCount}</strong> parts</span>
                            <span><strong>${sha.totalToolpath.toFixed(2)}</strong>m TP</span>
                            <span><strong>${sha.totalHDrills}</strong> HD</span>
                            <span><strong>${sha.totalVDrills}</strong> VD</span>
                            <span><strong>${sha.totalEdgeband.toFixed(2)}</strong>m EB</span>
                            <span><strong>${sha.totalMiters}</strong> mit</span>
                            <span><strong>${sha.totalP2P}</strong> P2P</span>
                        </div>
                    </div>
                    <div id="${sheetId}-body" class="accordion-body" style="display:none;">
                        <table class="parts-table">
                            <thead>
                                <tr>
                                    <th>Part Name</th>
                                    <th>Size (mm)</th>
                                    <th>Area (m²)</th>
                                    <th>ToolPath (m)</th>
                                    <th>H.Drill</th>
                                    <th>V.Drill</th>
                                    <th>Edge (m)</th>
                                    <th>Product</th>
                                </tr>
                            </thead>
                            <tbody>
                `;

                // ---- PARTS ROWS ----
                (sheet.parts || []).forEach(part => {
                    const p2pBadge = part.is_p2p
                        ? ' <span class="badge p2p">P2P</span>' : '';
                    const miterBadge = part.is_miter
                        ? ' <span class="badge miter">Miter</span>' : '';

                    html += `
                                <tr>
                                    <td class="part-name-cell">${part.name}${p2pBadge}${miterBadge}</td>
                                    <td>${part.length_mm} x ${part.width_mm}</td>
                                    <td>${(part.area_sqm || 0).toFixed(4)}</td>
                                    <td>${(part.toolpath_m || 0).toFixed(2)}</td>
                                    <td>${part.h_drills || '-'}</td>
                                    <td>${part.v_drills || '-'}</td>
                                    <td>${(part.edgeband_m || 0).toFixed(2)}</td>
                                    <td>${part.product_name} <span class="product-qty">(x${part.product_qty})</span></td>
                                </tr>
                    `;
                });

                html += `
                            </tbody>
                        </table>
                    </div>
                </div>`;  // close level-3 sheet
            });

            html += `</div></div>`;  // close level-2 material body + accordion
        });

        html += `</div></div>`;  // close level-1 station body + accordion
    });

    container.innerHTML = html;
}
```

---

## PHASE 7: CSS for Three-Level Accordion

### Step 7.1 — Base Accordion Styles (shared across all levels)

```css
.accordion {
    margin-bottom: 2px;
    border-radius: 6px;
    overflow: hidden;
}

.accordion-header {
    display: flex;
    align-items: center;
    padding: 12px 16px;
    cursor: pointer;
    transition: background 0.2s;
    gap: 12px;
}

.accordion-header:hover {
    filter: brightness(1.15);
}

.accordion-header .expand-icon {
    font-size: 0.85rem;
    width: 18px;
    flex-shrink: 0;
    transition: transform 0.2s;
}

.accordion-title {
    font-weight: 600;
    min-width: 120px;
}

.accordion-metrics {
    display: flex;
    gap: 16px;
    color: var(--text-secondary);
    font-size: 0.82rem;
    flex-wrap: wrap;
    margin-left: auto;
}

.accordion-metrics span strong {
    color: var(--accent-yellow);
}

.accordion-body {
    /* animated reveal could be added later */
}
```

### Step 7.2 — Level 1: Station (GREEN)

```css
.accordion.level-1 {
    border: 1px solid rgba(34, 197, 94, 0.3);
    margin-bottom: 6px;
}

.level-1-header {
    background: var(--bg-level-1);
    border-left: 4px solid var(--accent-green);
}

.level-1-header:hover {
    background: var(--bg-surface-hover);
}

.level-1-header.expanded {
    border-bottom: 1px solid var(--accent-green);
}

.level-1-header .expand-icon {
    color: var(--accent-green);
}

.level-1-title {
    color: var(--accent-green);
    font-size: 1.0rem;
}

.accordion.level-1 > .accordion-body {
    background: var(--bg-primary);
    padding: 8px 12px;
}
```

### Step 7.3 — Level 2: Material (YELLOW)

```css
.accordion.level-2 {
    border: 1px solid rgba(234, 179, 8, 0.2);
    margin-bottom: 4px;
}

.level-2-header {
    background: var(--bg-level-2);
    border-left: 4px solid var(--accent-yellow);
    padding: 10px 14px;
}

.level-2-header:hover {
    background: rgba(234, 179, 8, 0.08);
}

.level-2-header.expanded {
    border-bottom: 1px solid var(--accent-yellow);
}

.level-2-header .expand-icon {
    color: var(--accent-yellow);
}

.level-2-title {
    color: var(--accent-yellow);
    font-size: 0.92rem;
}

.accordion.level-2 > .accordion-body {
    background: var(--bg-level-2);
    padding: 6px 10px;
}
```

### Step 7.4 — Level 3: Sheet (CYAN)

```css
.accordion.level-3 {
    border: 1px solid rgba(6, 182, 212, 0.15);
    margin-bottom: 2px;
}

.level-3-header {
    background: var(--bg-level-3);
    border-left: 4px solid var(--accent-cyan);
    padding: 8px 12px;
}

.level-3-header:hover {
    background: rgba(6, 182, 212, 0.06);
}

.level-3-header.expanded {
    border-bottom: 1px solid var(--accent-cyan);
}

.level-3-header .expand-icon {
    color: var(--accent-cyan);
}

.level-3-title {
    color: var(--accent-cyan);
    font-size: 0.88rem;
}

.sheet-size {
    color: var(--text-secondary);
    font-size: 0.82rem;
    margin-left: 8px;
}

.accordion.level-3 > .accordion-body {
    background: var(--bg-level-4);
    padding: 4px 8px;
}
```

### Step 7.5 — Parts Table (inside Level 3)

```css
.parts-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.8rem;
}

.parts-table thead th {
    background: var(--bg-surface);
    color: var(--accent-green);
    padding: 7px 10px;
    text-align: left;
    font-weight: 600;
    border-bottom: 2px solid var(--accent-green);
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

.parts-table tbody tr {
    border-bottom: 1px solid var(--border);
}

.parts-table tbody tr:nth-child(even) {
    background: rgba(255, 255, 255, 0.02);
}

.parts-table tbody tr:hover {
    background: var(--bg-surface-hover);
}

.parts-table tbody td {
    padding: 5px 10px;
    color: var(--text-primary);
}

.part-name-cell {
    font-weight: 500;
}

/* Badges */
.badge {
    display: inline-block;
    padding: 1px 5px;
    border-radius: 3px;
    font-size: 0.65rem;
    font-weight: 700;
    margin-left: 4px;
    vertical-align: middle;
}

.badge.p2p {
    background: var(--accent-yellow-dim);
    color: var(--accent-yellow);
    border: 1px solid var(--accent-yellow);
}

.badge.miter {
    background: rgba(239, 68, 68, 0.15);
    color: #ef4444;
    border: 1px solid #ef4444;
}

.product-qty {
    color: var(--text-secondary);
    font-size: 0.78rem;
}
```

---

## PHASE 8: Visual Depth Cues

Each nesting level gets progressively:
- **Darker background** (bg-level-1 → bg-level-2 → bg-level-3 → bg-level-4)
- **Smaller font** (1.0rem → 0.92rem → 0.88rem → 0.8rem)
- **More left indent** (via padding inside accordion-body)
- **Thinner borders**
- **Different accent color** (green → yellow → cyan)

This creates a clear visual hierarchy so users always know their depth.

```
Depth 0: Summary Cards        - bg: dark, full-width
Depth 1: Station (GREEN)      - bg: #1a1a2e, left-border green, font 1.0rem
Depth 2: Material (YELLOW)    - bg: #151525, left-border yellow, font 0.92rem
Depth 3: Sheet (CYAN)         - bg: #111120, left-border cyan, font 0.88rem
Depth 4: Parts Table          - bg: #0d0d1a, green column headers, font 0.8rem
```

---

## WHAT GETS REMOVED (from current code)

### From `app.js`:
- The entire flat `unified-data-table` HTML generation
- All rowspan merging logic: `stationRowCount`, `materialRowCount`, `sheetRowCount`
- All first-row tracking: `stationFirstRow`, `materialFirstRow`, `sheetFirstRow`
- The `<colgroup>` with fixed column widths

### From `styles.css`:
- `.unified-data-table` and all related styles
- `.station-cell` (rowspan merged station column)
- `.material-cell` (rowspan merged material column)
- All light-mode colors

## WHAT GETS ADDED

### To `app.js`:
- `computeStationAggregates(station)` — aggregate station metrics
- `computeMaterialAggregates(material)` — aggregate material metrics
- `computeSheetAggregates(sheet)` — aggregate sheet metrics
- `toggleAccordion(id)` — universal toggle for all 3 levels
- Rewritten `displayWorkOrderProcessing()` — 3-level nested accordion builder

### To `styles.css`:
- Full dark mode color scheme (`:root` variables)
- `.accordion` base styles (shared)
- `.level-1-header`, `.level-1-title` (station — green)
- `.level-2-header`, `.level-2-title` (material — yellow)
- `.level-3-header`, `.level-3-title`, `.sheet-size` (sheet — cyan)
- `.accordion-metrics` (summary metrics bar)
- `.parts-table` (flat table inside sheet accordion)
- `.badge.p2p`, `.badge.miter` (updated for dark mode)
- All depth background variables

---

## EXECUTION ORDER

| Step | File | What | Time Est. |
|------|------|------|-----------|
| 1 | `styles.css` | Replace all colors → dark mode green/yellow/cyan | 30 min |
| 2 | `styles.css` | Add base accordion CSS | 10 min |
| 3 | `styles.css` | Add level-1 station CSS (green) | 10 min |
| 4 | `styles.css` | Add level-2 material CSS (yellow) | 10 min |
| 5 | `styles.css` | Add level-3 sheet CSS (cyan) | 10 min |
| 6 | `styles.css` | Add parts-table CSS + badges | 10 min |
| 7 | `app.js` | Add 3 aggregate functions | 15 min |
| 8 | `app.js` | Add `toggleAccordion()` function | 5 min |
| 9 | `app.js` | Rewrite `displayWorkOrderProcessing()` with 3-level nesting | 45 min |
| 10 | `app.js` | Remove old rowspan/flat-table code | 5 min |
| 11 | `index.html` | No changes needed | 0 min |
| 12 | Test | Verify all 3 views + 3 accordion levels + dark mode | 20 min |

**Total estimated: ~2.5 hours**

---

## FILES TO MODIFY

1. **`webapp/frontend/css/styles.css`** — Full dark mode + 3-level accordion CSS
2. **`webapp/frontend/js/app.js`** — 3 aggregation functions + toggle + rewrite display
3. **`webapp/frontend/index.html`** — No changes (all dynamic)
