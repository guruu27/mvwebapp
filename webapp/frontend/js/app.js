// Microvellum Database Web App - Frontend JavaScript

// Auto-detect: use same hostname as the page, always port 8001
const API_BASE = `http://${window.location.hostname || 'localhost'}:8001`;
let currentProject = null;
let currentSchema = null;

// Initialize app
document.addEventListener('DOMContentLoaded', () => {
    loadProjects();
    setupEventListeners();
});

function setupEventListeners() {
    document.getElementById('back-to-projects')?.addEventListener('click', () => showProjectView());
    document.getElementById('back-to-workorders')?.addEventListener('click', () => showWorkOrderView(currentProject));
}

// API Calls
async function apiCall(endpoint, options = {}) {
    try {
        const response = await fetch(`${API_BASE}${endpoint}`, options);
        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail || 'API request failed');
        }
        return await response.json();
    } catch (error) {
        showError(error.message);
        throw error;
    }
}

// Load Projects
async function loadProjects() {
    showLoading(true);
    try {
        const data = await apiCall('/projects');
        displayProjects(data);
        showProjectView();
    } catch (error) {
        console.error('Failed to load projects:', error);
    } finally {
        showLoading(false);
    }
}

// Display Projects
function displayProjects(projects) {
    const grid = document.getElementById('project-grid');
    grid.innerHTML = '';

    projects.forEach(project => {
        const card = document.createElement('div');
        card.className = 'project-card';
        card.innerHTML = `
            <div class="project-number">Project ${project.project_number}</div>
            <div class="project-name">${project.project_name}</div>
            <div class="project-stats">
                <span>${project.work_order_count} Work Orders</span>
            </div>
        `;
        card.addEventListener('click', () => loadWorkOrders(project.project_number, project.project_name));
        grid.appendChild(card);
    });
}

// Load Work Orders
async function loadWorkOrders(projectNumber, projectName) {
    showLoading(true);
    currentProject = { number: projectNumber, name: projectName };

    try {
        const data = await apiCall(`/projects/${projectNumber}/workorders`);
        displayWorkOrders(data);
        showWorkOrderView(currentProject);
    } catch (error) {
        console.error('Failed to load work orders:', error);
    } finally {
        showLoading(false);
    }
}

// Display Work Orders
function displayWorkOrders(workorders) {
    const grid = document.getElementById('workorder-grid');
    grid.innerHTML = '';

    workorders.forEach(wo => {
        const card = document.createElement('div');
        card.className = 'workorder-card';
        card.innerHTML = `
            <div class="wo-header">
                <div class="wo-number">${wo.drawing_number}</div>
                <div class="wo-schema">${wo.schema_name}</div>
            </div>
            <div class="wo-name">${wo.work_order_name}</div>
            <div class="wo-stats">
                <div class="stat">
                    <span class="stat-label">Tables</span>
                    <span class="stat-value">${wo.table_count}</span>
                </div>
                <div class="stat">
                    <span class="stat-label">Products</span>
                    <span class="stat-value">${wo.products_count}</span>
                </div>
                <div class="stat">
                    <span class="stat-label">Parts</span>
                    <span class="stat-value">${wo.parts_count}</span>
                </div>
            </div>
        `;
        card.addEventListener('click', () => loadSchema(wo.schema_name));
        grid.appendChild(card);
    });
}

// Load Schema Details
async function loadSchema(schemaName) {
    showLoading(true);
    currentSchema = schemaName;

    try {
        const woDetails = await apiCall(`/schema/${schemaName}/workorder-details`);
        displayWorkOrderProcessing(woDetails);
        showSchemaView();
    } catch (error) {
        console.error('Failed to load schema:', error);
    } finally {
        showLoading(false);
    }
}

// ================================================================
// AGGREGATE FUNCTIONS
// ================================================================

function computeSheetAggregates(sheet) {
    const parts = sheet.parts || [];
    return {
        partCount: parts.length,
        totalToolpath: parts.reduce((s, p) => s + (p.toolpath_m || 0), 0),
        totalHDrills: parts.reduce((s, p) => s + (p.h_drills || 0), 0),
        totalVDrills: parts.reduce((s, p) => s + (p.v_drills || 0), 0),
        totalEdgeband: parts.reduce((s, p) => s + (p.edgeband_m || 0), 0),
        totalMiters: parts.filter(p => p.is_miter).length,
        totalP2P: parts.filter(p => p.is_p2p).length,
        totalArea: parts.reduce((s, p) => s + (p.area_sqm || 0), 0),
    };
}

function computeMaterialAggregates(material) {
    let totalSheets = 0, totalParts = 0, totalToolpath = 0;
    let totalHDrills = 0, totalVDrills = 0, totalEdgeband = 0;
    let totalMiters = 0, totalP2P = 0, totalArea = 0;

    (material.sheets || []).forEach(sheet => {
        totalSheets++;
        (sheet.parts || []).forEach(part => {
            totalParts++;
            totalToolpath += part.toolpath_m || 0;
            totalHDrills += part.h_drills || 0;
            totalVDrills += part.v_drills || 0;
            totalEdgeband += part.edgeband_m || 0;
            totalArea += part.area_sqm || 0;
            if (part.is_miter) totalMiters++;
            if (part.is_p2p) totalP2P++;
        });
    });

    return { totalSheets, totalParts, totalToolpath, totalHDrills, totalVDrills, totalEdgeband, totalMiters, totalP2P, totalArea };
}

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
                totalHDrills += part.h_drills || 0;
                totalVDrills += part.v_drills || 0;
                totalEdgeband += part.edgeband_m || 0;
                totalArea += part.area_sqm || 0;
                if (part.is_miter) totalMiters++;
                if (part.is_p2p) totalP2P++;
            });
        });
    });

    return { totalMaterials, totalSheets, totalParts, totalToolpath, totalHDrills, totalVDrills, totalEdgeband, totalMiters, totalP2P, totalArea };
}

// ================================================================
// TOGGLE ACCORDION (Universal)
// ================================================================

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

// ================================================================
// DISPLAY PRODUCTION PLAN: 3-Level Accordion
// ================================================================
function displayWorkOrderProcessing(data) {
    const container = document.getElementById('processing-tree');
    container.innerHTML = '';

    if (!data.processing_stations || data.processing_stations.length === 0) {
        container.innerHTML = '<p class="no-data">No processing data available</p>';
        return;
    }

    const s = data.summary || {};

    // ---- SUMMARY CARDS ----
    let html = `
        <div class="summary-bar">
            <div class="summary-card nesting">
                <div class="summary-icon">CNC</div>
                <div class="summary-body">
                    <div class="summary-title">CNC Nesting</div>
                    <div class="summary-metrics">
                        <span><strong>${s.nest_sheets || 0}</strong> sheets</span>
                        <span><strong>${s.nest_parts || 0}</strong> parts</span>
                        <span>TP: <strong>${((s.total_toolpath_mm || 0) / 1000).toFixed(1)}</strong>m</span>
                    </div>
                    ${s.cnc_hours ? `<div class="summary-hours">CNC: ${Number(s.cnc_hours).toFixed(2)} hrs <span class="hours-formula">(TP / 8m/min)</span></div>` : ''}
                </div>
            </div>
            <div class="summary-card panel">
                <div class="summary-icon">ELIX</div>
                <div class="summary-body">
                    <div class="summary-title">Elix (H.Drills)</div>
                    <div class="summary-metrics">
                        <span><strong>${s.total_h_drills || 0}</strong> drills</span>
                        <span><strong>${s.panel_sheets || 0}</strong> sheets</span>
                    </div>
                    ${s.elix_hours ? `<div class="summary-hours">Elix: ${Number(s.elix_hours).toFixed(2)} hrs <span class="hours-formula">(${s.total_h_drills || 0} x 8s)</span></div>` : ''}
                </div>
            </div>
            <div class="summary-card edge">
                <div class="summary-icon">EB</div>
                <div class="summary-body">
                    <div class="summary-title">Edgebanding</div>
                    <div class="summary-metrics">
                        <span><strong>${((s.total_edgeband_mm || 0) / 1000).toFixed(1)}</strong>m total</span>
                        <span><strong>${s.edge_linft || 0}</strong> lin ft</span>
                    </div>
                    ${s.edging_hours ? `<div class="summary-hours">Edging: ${Number(s.edging_hours).toFixed(2)} hrs <span class="hours-formula">(12m/min)</span></div>` : ''}
                </div>
            </div>
            <div class="summary-card operations">
                <div class="summary-icon">OPS</div>
                <div class="summary-body">
                    <div class="summary-title">Operations</div>
                    <div class="summary-metrics">
                        <span>P2P: <strong>${s.p2p || 0}</strong></span>
                        <span>Miter: <strong>${s.total_miters || 0}</strong></span>
                        <span>Solid: <strong>${s.solid || '-'}</strong></span>
                    </div>
                    ${s.miter_hours ? `<div class="summary-hours">Miter: ${Number(s.miter_hours).toFixed(2)} hrs <span class="hours-formula">(${s.total_miters || 0} x 8min)</span></div>` : ''}
                </div>
            </div>
            <div class="summary-card totals">
                <div class="summary-icon">TOT</div>
                <div class="summary-body">
                    <div class="summary-title">Totals</div>
                    <div class="summary-metrics">
                        <span><strong>${s.products || 0}</strong> products</span>
                        <span><strong>${s.total_parts || 0}</strong> parts</span>
                    </div>
                    <div class="summary-hours">Total: ${(Number(s.cnc_hours || 0) + Number(s.elix_hours || 0) + Number(s.edging_hours || 0) + Number(s.miter_hours || 0)).toFixed(2)} hrs</div>
                    <div class="summary-batch">${s.batch_name || ''}</div>
                </div>
            </div>
        </div>
    `;

    // ---- LEVEL 1: STATION ACCORDIONS ----
    data.processing_stations.forEach((station, si) => {
        const sa = computeStationAggregates(station);
        const stationId = `s${si}`;

        html += `
        <div class="accordion level-1">
            <div class="accordion-header level-1-header" onclick="toggleAccordion('${stationId}')">
                <span class="expand-icon" id="${stationId}-icon">▶</span>
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
            <div id="${stationId}-body" class="accordion-body" style="display:none;">
        `;

        // ---- LEVEL 2: MATERIAL ACCORDIONS ----
        (station.materials || []).forEach((material, mi) => {
            const ma = computeMaterialAggregates(material);
            const materialId = `s${si}-m${mi}`;

            html += `
            <div class="accordion level-2">
                <div class="accordion-header level-2-header" onclick="toggleAccordion('${materialId}')">
                    <span class="expand-icon" id="${materialId}-icon">▶</span>
                    <span class="accordion-title level-2-title">${material.material_name}</span>
                    <div class="accordion-metrics">
                        <span><strong>${ma.totalSheets}</strong> sheets</span>
                        <span><strong>${ma.totalParts}</strong> parts</span>
                        <span><strong>${ma.totalToolpath.toFixed(1)}</strong>m TP</span>
                        <span><strong>${ma.totalEdgeband.toFixed(1)}</strong>m EB</span>
                        <span><strong>${ma.totalMiters}</strong> mit</span>
                    </div>
                </div>
                <div id="${materialId}-body" class="accordion-body" style="display:none;">
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
                    const p2pBadge = part.is_p2p ? ' <span class="badge p2p">P2P</span>' : '';
                    const miterBadge = part.is_miter ? ' <span class="badge miter">Miter</span>' : '';

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
                </div>`; // close level-3
            });

            html += `</div></div>`; // close level-2
        });

        html += `</div></div>`; // close level-1
    });

    container.innerHTML = html;
}


// View Management
function showLoading(show) {
    document.getElementById('loading').style.display = show ? 'flex' : 'none';
}

function showProjectView() {
    hideAllViews();
    document.getElementById('project-view').style.display = 'block';
}

function showWorkOrderView(project) {
    hideAllViews();
    document.getElementById('current-project').textContent = `Project ${project.number} - ${project.name}`;
    document.getElementById('workorder-view').style.display = 'block';
}

function showSchemaView() {
    hideAllViews();
    document.getElementById('current-schema').textContent = currentSchema;
    document.getElementById('schema-view').style.display = 'block';
}

function hideAllViews() {
    document.querySelectorAll('.view').forEach(view => {
        view.style.display = 'none';
    });
}

function showError(message) {
    const errorDiv = document.getElementById('error-message');
    errorDiv.textContent = message;
    errorDiv.style.display = 'block';
    setTimeout(() => {
        errorDiv.style.display = 'none';
    }, 5000);
}

// Modal Functions
function openQueryBuilder() {
    document.getElementById('query-modal').style.display = 'flex';
    document.getElementById('sql-query').value = `SELECT TOP 100 * FROM [${currentSchema}].Parts`;
}

function openSheetTracking() {
    document.getElementById('sheet-modal').style.display = 'flex';
}

function closeModal(modalId) {
    document.getElementById(modalId).style.display = 'none';
}

async function executeQuery() {
    const query = document.getElementById('sql-query').value;
    const resultsDiv = document.getElementById('query-results');
    resultsDiv.innerHTML = '<div class="loading-small">Executing...</div>';

    try {
        const data = await apiCall('/query', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ query })
        });

        displayQueryResults(data, resultsDiv);
    } catch (error) {
        resultsDiv.innerHTML = `<div class="error">Error: ${error.message}</div>`;
    }
}

function displayQueryResults(data, container) {
    if (!data.rows || data.rows.length === 0) {
        container.innerHTML = '<div class="no-results">No results</div>';
        return;
    }

    let html = `<div class="results-info">Returned ${data.row_count} rows in ${data.execution_time.toFixed(3)}s</div>`;
    html += '<div class="table-container"><table class="results-table"><thead><tr>';

    data.columns.forEach(col => {
        html += `<th>${col}</th>`;
    });
    html += '</tr></thead><tbody>';

    data.rows.forEach(row => {
        html += '<tr>';
        data.columns.forEach(col => {
            html += `<td>${row[col] || ''}</td>`;
        });
        html += '</tr>';
    });

    html += '</tbody></table></div>';
    container.innerHTML = html;
}

async function runSheetTracking() {
    const schema = currentSchema;
    const scrappedSheet = document.getElementById('scrapped-sheet').value;
    const scrappedStation = document.getElementById('scrapped-station').value;
    const resultsDiv = document.getElementById('sheet-results');

    resultsDiv.innerHTML = '<div class="loading-small">Running...</div>';

    try {
        const data = await apiCall('/sheet-tracking', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                schema_name: schema,
                scrapped_sheet_number: scrappedSheet ? parseInt(scrappedSheet) : null,
                scrapped_station: scrappedStation ? parseInt(scrappedStation) : null
            })
        });

        displayQueryResults(data, resultsDiv);
    } catch (error) {
        resultsDiv.innerHTML = `<div class="error">Error: ${error.message}</div>`;
    }
}

function viewRelationships() {
    alert('Relationships viewer - Coming soon!');
}

function exportSchema() {
    alert('Schema export - Coming soon!');
}

function showTableDetails(tableName) {
    alert(`Table details for ${tableName} - Coming soon!`);
}

// Close modals when clicking outside
window.addEventListener('click', (e) => {
    if (e.target.classList.contains('modal')) {
        e.target.style.display = 'none';
    }
});
