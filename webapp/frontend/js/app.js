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
// DISPLAY PRODUCTION PLAN: Summary Cards + Detail Table
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
                    </div>
                    ${s.nesting_hours ? `<div class="summary-hours">${Number(s.nesting_hours).toFixed(1)} hrs</div>` : ''}
                </div>
            </div>
            <div class="summary-card panel">
                <div class="summary-icon">SAW</div>
                <div class="summary-body">
                    <div class="summary-title">Panel Saw</div>
                    <div class="summary-metrics">
                        <span><strong>${s.panel_sheets || 0}</strong> sheets</span>
                        <span><strong>${s.panel_parts || 0}</strong> parts</span>
                    </div>
                    ${s.panel_hours ? `<div class="summary-hours">${Number(s.panel_hours).toFixed(1)} hrs</div>` : ''}
                </div>
            </div>
            <div class="summary-card edge">
                <div class="summary-icon">EB</div>
                <div class="summary-body">
                    <div class="summary-title">Edgebanding</div>
                    <div class="summary-metrics">
                        <span><strong>${s.edge_linft || 0}</strong> lin ft</span>
                    </div>
                    ${s.edging_hours ? `<div class="summary-hours">${Number(s.edging_hours).toFixed(1)} hrs</div>` : ''}
                </div>
            </div>
            <div class="summary-card operations">
                <div class="summary-icon">OPS</div>
                <div class="summary-body">
                    <div class="summary-title">Operations</div>
                    <div class="summary-metrics">
                        <span>P2P: <strong>${s.p2p || 0}</strong></span>
                        <span>Miter: <strong>${s.miter || 0}</strong></span>
                        <span>Solid: <strong>${s.solid || '-'}</strong></span>
                    </div>
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
                    <div class="summary-batch">${s.batch_name || ''}</div>
                </div>
            </div>
        </div>
    `;

    // ---- DETAIL TABLE ----
    html += `
        <table class="unified-data-table">
            <colgroup>
                <col style="width: 120px;">
                <col style="width: 250px;">
                <col style="width: 55px;">
                <col style="width: 120px;">
                <col style="width: 90px;">
                <col style="width: 65px;">
                <col style="width: 65px;">
                <col style="width: 80px;">
                <col style="width: 55px;">
                <col style="width: 200px;">
                <col style="width: 200px;">
            </colgroup>
            <thead>
                <tr>
                    <th rowspan="2">Processing Station</th>
                    <th rowspan="2">Material</th>
                    <th colspan="7" style="text-align:center;">Sheet Data</th>
                    <th colspan="2" style="text-align:center;">Parts / Products</th>
                </tr>
                <tr>
                    <th>Sheet#</th>
                    <th>Size (mm)</th>
                    <th>Tool Path (m)</th>
                    <th>H.Drill</th>
                    <th>V.Drill</th>
                    <th>Edge (m)</th>
                    <th>Miter</th>
                    <th>Parts</th>
                    <th>Products</th>
                </tr>
            </thead>
            <tbody>
    `;

    // Build rows from the hierarchical data
    data.processing_stations.forEach(station => {
        let stationFirstRow = true;
        let stationRowCount = 0;
        station.materials.forEach(mat => {
            mat.sheets.forEach(sheet => {
                stationRowCount += Math.max(sheet.parts.length, 1);
            });
        });

        station.materials.forEach(material => {
            let materialFirstRow = true;
            let materialRowCount = 0;
            material.sheets.forEach(sheet => {
                materialRowCount += Math.max(sheet.parts.length, 1);
            });

            material.sheets.forEach(sheet => {
                const parts = sheet.parts || [];
                const sheetRowCount = Math.max(parts.length, 1);
                let sheetFirstRow = true;

                // Aggregate sheet-level metrics
                const sheetToolPath = parts.reduce((sum, p) => sum + p.toolpath_m, 0);
                const sheetEdgeBand = parts.reduce((sum, p) => sum + p.edgeband_m, 0);
                const sheetHDrills = parts.reduce((sum, p) => sum + p.h_drills, 0);
                const sheetVDrills = parts.reduce((sum, p) => sum + p.v_drills, 0);
                const sheetMiter = parts.filter(p => p.is_miter).length;

                if (parts.length === 0) {
                    html += `<tr>`;
                    if (stationFirstRow) {
                        html += `<td rowspan="${stationRowCount}" class="station-cell">${station.station_name}</td>`;
                        stationFirstRow = false;
                    }
                    if (materialFirstRow) {
                        html += `<td rowspan="${materialRowCount}" class="material-cell">${material.material_name}</td>`;
                        materialFirstRow = false;
                    }
                    html += `
                        <td>${sheet.sheet_number}</td>
                        <td>${sheet.length_mm} x ${sheet.width_mm}</td>
                        <td>-</td><td>-</td><td>-</td><td>-</td><td>-</td>
                        <td class="parts-cell">-</td>
                        <td class="products-cell">-</td>
                    </tr>`;
                } else {
                    parts.forEach((part, partIdx) => {
                        html += `<tr>`;

                        if (stationFirstRow) {
                            html += `<td rowspan="${stationRowCount}" class="station-cell">${station.station_name}</td>`;
                            stationFirstRow = false;
                        }

                        if (materialFirstRow) {
                            html += `<td rowspan="${materialRowCount}" class="material-cell">${material.material_name}</td>`;
                            materialFirstRow = false;
                        }

                        if (sheetFirstRow) {
                            html += `
                                <td rowspan="${sheetRowCount}">${sheet.sheet_number}</td>
                                <td rowspan="${sheetRowCount}">${sheet.length_mm} x ${sheet.width_mm}</td>
                                <td rowspan="${sheetRowCount}">${sheetToolPath.toFixed(2)}</td>
                                <td rowspan="${sheetRowCount}">${sheetHDrills || '-'}</td>
                                <td rowspan="${sheetRowCount}">${sheetVDrills || '-'}</td>
                                <td rowspan="${sheetRowCount}">${sheetEdgeBand.toFixed(2)}</td>
                                <td rowspan="${sheetRowCount}">${sheetMiter || '-'}</td>
                            `;
                            sheetFirstRow = false;
                        }

                        const p2pBadge = part.is_p2p ? ' <span class="badge p2p">P2P</span>' : '';
                        const miterBadge = part.is_miter ? ' <span class="badge miter">Miter</span>' : '';
                        html += `<td class="parts-cell">${part.name}${p2pBadge}${miterBadge}<br><span class="part-dims">${part.length_mm}x${part.width_mm} | ${part.area_sqm.toFixed(4)} m&sup2;</span></td>`;
                        html += `<td class="products-cell">${part.product_name} <span class="product-qty">(x${part.product_qty})</span></td>`;

                        html += `</tr>`;
                    });
                }
            });
        });
    });

    html += `
            </tbody>
        </table>
    `;

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
