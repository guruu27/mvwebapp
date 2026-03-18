/**
 * Microvellum Database Explorer - Frontend JavaScript
 * A single-page application for exploring manufacturing work order data.
 */

// API BASE URL - auto-detect from current location
const API_BASE = `http://${window.location.hostname || 'localhost'}:8000`;

// State
let currentProject = null;
let currentSchema = null;

// ==================== API Communication Layer ====================

/**
 * Generic API call wrapper
 */
async function apiCall(endpoint, options = {}) {
    try {
        const response = await fetch(`${API_BASE}${endpoint}`, {
            ...options,
            headers: {
                'Content-Type': 'application/json',
                ...options.headers
            }
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail || error.message || 'API request failed');
        }
        
        return await response.json();
    } catch (error) {
        showError(error.message);
        throw error;
    }
}

// ==================== View Navigation ====================

/**
 * Hide all views
 */
function hideAllViews() {
    document.querySelectorAll('.view').forEach(view => {
        view.style.display = 'none';
    });
}

/**
 * Show project view
 */
function showProjectView() {
    hideAllViews();
    document.getElementById('project-view').style.display = 'block';
}

/**
 * Show work order view
 */
function showWorkOrderView(project) {
    hideAllViews();
    document.getElementById('workorder-view').style.display = 'block';
    document.getElementById('current-project').textContent = 
        `Project ${project.number} - ${project.name}`;
}

/**
 * Show schema view
 */
function showSchemaView() {
    hideAllViews();
    document.getElementById('schema-view').style.display = 'block';
    document.getElementById('current-schema').textContent = currentSchema;
}

// ==================== Error Handling ====================

/**
 * Show error message
 */
function showError(message) {
    const errorEl = document.getElementById('error-message');
    errorEl.textContent = message;
    errorEl.style.display = 'block';
    
    // Auto-hide after 5 seconds
    setTimeout(() => {
        errorEl.style.display = 'none';
    }, 5000);
}

/**
 * Show/hide loading spinner
 */
function showLoading(show) {
    document.getElementById('loading').style.display = show ? 'block' : 'none';
}

// ==================== Project Display ====================

/**
 * Load all projects
 */
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

/**
 * Display projects as cards
 */
function displayProjects(projects) {
    const grid = document.getElementById('project-grid');
    grid.innerHTML = '';
    
    if (!projects || projects.length === 0) {
        grid.innerHTML = '<p class="no-data">No projects found</p>';
        return;
    }
    
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
        card.onclick = () => loadWorkOrders(project.project_number, project.project_name);
        grid.appendChild(card);
    });
}

// ==================== Work Order Display ====================

/**
 * Load work orders for a project
 */
async function loadWorkOrders(projectNumber, projectName) {
    currentProject = { number: projectNumber, name: projectName };
    showLoading(true);
    
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

/**
 * Display work orders as cards
 */
function displayWorkOrders(workorders) {
    const grid = document.getElementById('workorder-grid');
    grid.innerHTML = '';
    
    if (!workorders || workorders.length === 0) {
        grid.innerHTML = '<p class="no-data">No work orders found</p>';
        return;
    }
    
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
                <div class="stat">Tables: ${wo.table_count}</div>
                <div class="stat">Products: ${wo.products_count}</div>
                <div class="stat">Parts: ${wo.parts_count}</div>
            </div>
        `;
        card.onclick = () => loadSchema(wo.schema_name);
        grid.appendChild(card);
    });
}

// ==================== Schema/Work Order Details Display ====================

/**
 * Load schema details
 */
async function loadSchema(schemaName) {
    currentSchema = schemaName;
    showLoading(true);
    
    try {
        const data = await apiCall(`/schema/${schemaName}/workorder-details`);
        displayWorkOrderProcessing(data);
        showSchemaView();
    } catch (error) {
        console.error('Failed to load schema details:', error);
    } finally {
        showLoading(false);
    }
}

/**
 * Display work order processing data (production plan)
 */
function displayWorkOrderProcessing(data) {
    const container = document.getElementById('processing-tree');
    
    if (!data || !data.processing_stations || data.processing_stations.length === 0) {
        container.innerHTML = '<p class="no-data">No processing data available</p>';
        return;
    }
    
    const summary = data.summary;
    
    // Build summary cards HTML
    let html = `
        <div class="summary-bar">
            <div class="summary-card nesting">
                <div class="summary-icon">CNC</div>
                <div class="summary-title">Nesting</div>
                <div class="summary-metrics">
                    <div>${summary.nest_sheets || 0} sheets</div>
                    <div>${summary.nest_parts || 0} parts</div>
                </div>
                <div class="summary-hours">${summary.nesting_hours || 0} hrs</div>
            </div>
            <div class="summary-card panel">
                <div class="summary-icon">SAW</div>
                <div class="summary-title">Panel Saw</div>
                <div class="summary-metrics">
                    <div>${summary.panel_sheets || 0} sheets</div>
                    <div>${summary.panel_parts || 0} parts</div>
                </div>
                <div class="summary-hours">${summary.panel_hours || 0} hrs</div>
            </div>
            <div class="summary-card edge">
                <div class="summary-icon">EB</div>
                <div class="summary-title">Edgebanding</div>
                <div class="summary-metrics">
                    <div>${Math.round(summary.edge_ft || 0)} ft</div>
                </div>
                <div class="summary-hours">${summary.edge_hours || 0} hrs</div>
            </div>
            <div class="summary-card operations">
                <div class="summary-icon">OPS</div>
                <div class="summary-title">Operations</div>
                <div class="summary-metrics">
                    <div>P2P: ${summary.p2p_count || 0}</div>
                    <div>Miter: ${summary.miter_count || 0}</div>
                    <div>Solid: ${summary.solid_qty || 0}</div>
                </div>
            </div>
            <div class="summary-card totals">
                <div class="summary-icon">TOT</div>
                <div class="summary-title">Totals</div>
                <div class="summary-metrics">
                    <div>${summary.total_products || 0} products</div>
                    <div>${summary.total_parts || 0} parts</div>
                </div>
                <div class="summary-batch">${summary.batch_name || 'N/A'}</div>
            </div>
        </div>
    `;
    
    // Build detail table
    html += `
        <div class="table-box">
            <table class="unified-data-table">
                <colgroup>
                    <col class="col-station">
                    <col class="col-material">
                    <col class="col-sheet">
                    <col class="col-size">
                    <col class="col-toolpath">
                    <col class="col-hdrill">
                    <col class="col-vdrill">
                    <col class="col-edge">
                    <col class="col-miter">
                    <col class="col-parts">
                    <col class="col-products">
                </colgroup>
                <thead>
                    <tr>
                        <th>Processing Station</th>
                        <th>Material</th>
                        <th>Sheet#</th>
                        <th>Size (mm)</th>
                        <th>ToolPth (m)</th>
                        <th>H.Drll</th>
                        <th>V.Drll</th>
                        <th>Edge (m)</th>
                        <th>Miter</th>
                        <th>Parts</th>
                        <th>Products</th>
                    </tr>
                </thead>
                <tbody>
    `;
    
    // Track rowspans
    let stationRowCount = 0;
    let materialRowCount = 0;
    let sheetRowCount = 0;
    let stationFirstRow = true;
    let materialFirstRow = true;
    let sheetFirstRow = true;
    
    // Process each station, material, sheet
    data.processing_stations.forEach((station, stationIdx) => {
        stationFirstRow = true;
        let stationPartCount = 0;
        
        station.materials.forEach(material => {
            materialFirstRow = true;
            let materialPartCount = 0;
            
            material.sheets.forEach(sheet => {
                sheetFirstRow = true;
                
                // Aggregate sheet metrics
                let sheetToolPath = 0;
                let sheetEdgeBand = 0;
                let sheetHDrills = 0;
                let sheetVDrills = 0;
                let sheetMiter = 0;
                
                sheet.parts.forEach(part => {
                    sheetToolPath += part.toolpath_m || 0;
                    sheetEdgeBand += part.edgeband_m || 0;
                    sheetHDrills += part.h_drills || 0;
                    sheetVDrills += part.v_drills || 0;
                    if (part.is_miter) sheetMiter++;
                });
                
                // Each part is a row
                sheet.parts.forEach((part, partIdx) => {
                    const isFirstInStation = stationFirstRow;
                    const isFirstInMaterial = materialFirstRow;
                    const isFirstInSheet = sheetFirstRow;
                    
                    // Calculate rowspans
                    if (isFirstInStation) {
                        // Count remaining parts in this station
                        let remainingParts = 0;
                        for (let i = stationIdx; i < data.processing_stations.length; i++) {
                            const s = data.processing_stations[i];
                            for (let m = 0; m < s.materials.length; m++) {
                                const mat = s.materials[m];
                                for (let sh = 0; sh < mat.sheets.length; sh++) {
                                    const shet = mat.sheets[sh];
                                    if (i === stationIdx && m === materialIdx && sh === sheetIdx) {
                                        remainingParts += shet.parts.length - partIdx;
                                    } else {
                                        remainingParts += shet.parts.length;
                                    }
                                }
                            }
                        }
                        stationRowCount = remainingParts;
                    }
                    
                    // Determine classes
                    const rowClass = part.is_p2p ? 'p2p-row' : (part.is_miter ? 'miter-row' : '');
                    
                    html += `<tr class="${rowClass}">`;
                    
                    // Station cell
                    if (isFirstInStation) {
                        const rowspan = station.materials.reduce((sum, m) => 
                            sum + m.sheets.reduce((s, sh) => s + sh.parts.length, 0), 0);
                        html += `<td class="station-cell" rowspan="${rowspan}">
                            ${station.station_name}
                        </td>`;
                        stationFirstRow = false;
                    }
                    
                    // Material cell
                    if (isFirstInMaterial) {
                        const rowspan = material.sheets.reduce((sum, sh) => sum + sh.parts.length, 0);
                        html += `<td class="material-cell" rowspan="${rowspan}">
                            ${material.material_name}
                        </td>`;
                        materialFirstRow = false;
                    }
                    
                    // Sheet cell
                    if (isFirstInSheet) {
                        const rowspan = sheet.parts.length;
                        html += `<td class="sheet-cell" rowspan="${rowspan}">
                            ${sheet.sheet_number}
                        </td>
                        <td class="size-cell" rowspan="${rowspan}">
                            ${sheet.length_mm}x${sheet.width_mm}
                        </td>
                        <td class="metric-cell" rowspan="${rowspan}">
                            ${sheetToolPath.toFixed(2)}
                        </td>
                        <td class="metric-cell" rowspan="${rowspan}">
                            ${sheetHDrills}
                        </td>
                        <td class="metric-cell" rowspan="${rowspan}">
                            ${sheetVDrills}
                        </td>
                        <td class="metric-cell" rowspan="${rowspan}">
                            ${sheetEdgeBand.toFixed(2)}
                        </td>
                        <td class="metric-cell" rowspan="${rowspan}">
                            ${sheetMiter > 0 ? sheetMiter : '-'}
                        </td>`;
                        sheetFirstRow = false;
                    }
                    
                    // Parts cell
                    let partInfo = part.name;
                    if (part.is_p2p) partInfo += ' <span class="badge p2p">P2P</span>';
                    if (part.is_miter) partInfo += ' <span class="badge miter">Miter</span>';
                    partInfo += `<br><span class="part-dims">${part.length_mm}x${part.width_mm} | ${part.area_sqm} m²</span>`;
                    
                    html += `<td class="parts-cell">${partInfo}</td>`;
                    
                    // Products cell
                    html += `<td class="products-cell">
                        ${part.product_name} (x${part.product_qty})
                    </td>`;
                    
                    html += '</tr>';
                });
            });
        });
    });
    
    html += '</tbody></table></div>';
    
    container.innerHTML = html;
}

// ==================== Query Builder ====================

/**
 * Open query builder modal
 */
function openQueryBuilder() {
    const modal = document.getElementById('query-modal');
    modal.style.display = 'block';
    
    // Pre-fill with current schema
    if (currentSchema) {
        document.getElementById('sql-query').value = 
            `SELECT TOP 100 * FROM [${currentSchema}].Parts`;
    }
}

/**
 * Close query modal
 */
function closeQueryModal() {
    document.getElementById('query-modal').style.display = 'none';
}

/**
 * Execute SQL query
 */
async function executeQuery() {
    const query = document.getElementById('sql-query').value;
    const resultsDiv = document.getElementById('query-results');
    
    if (!query.trim()) {
        resultsDiv.innerHTML = '<p class="error">Please enter a query</p>';
        return;
    }
    
    resultsDiv.innerHTML = '<p>Executing...</p>';
    
    try {
        const data = await apiCall('/query', {
            method: 'POST',
            body: JSON.stringify({ query })
        });
        
        displayQueryResults(data, resultsDiv);
    } catch (error) {
        resultsDiv.innerHTML = `<p class="error">Error: ${error.message}</p>`;
    }
}

/**
 * Display query results in a table
 */
function displayQueryResults(data, container) {
    if (data.error) {
        container.innerHTML = `<p class="error">${data.error}</p>`;
        return;
    }
    
    if (!data.columns || data.columns.length === 0) {
        container.innerHTML = '<p>No results</p>';
        return;
    }
    
    let html = `<p>${data.row_count} rows (${data.execution_time}s)</p>`;
    html += '<div class="results-table-wrapper"><table class="results-table">';
    
    // Header
    html += '<thead><tr>';
    data.columns.forEach(col => {
        html += `<th>${col}</th>`;
    });
    html += '</tr></thead>';
    
    // Body
    html += '<tbody>';
    data.rows.forEach(row => {
        html += '<tr>';
        row.forEach(cell => {
            html += `<td>${cell !== null ? cell : ''}</td>`;
        });
        html += '</tr>';
    });
    html += '</tbody></table></div>';
    
    container.innerHTML = html;
}

// ==================== Sheet Tracking ====================

/**
 * Open sheet tracking modal
 */
function openSheetTracking() {
    document.getElementById('sheet-modal').style.display = 'block';
}

/**
 * Close sheet tracking modal
 */
function closeSheetModal() {
    document.getElementById('sheet-modal').style.display = 'none';
}

/**
 * Run sheet tracking analysis
 */
async function runSheetTracking() {
    const sheetNum = document.getElementById('scrapped-sheet').value;
    const stationNum = document.getElementById('scrapped-station').value;
    const resultsDiv = document.getElementById('sheet-results');
    
    if (!sheetNum || !stationNum) {
        resultsDiv.innerHTML = '<p class="error">Please enter both sheet number and station</p>';
        return;
    }
    
    resultsDiv.innerHTML = '<p>Analyzing...</p>';
    
    try {
        const data = await apiCall('/sheet-tracking', {
            method: 'POST',
            body: JSON.stringify({
                schema_name: currentSchema,
                scrapped_sheet_number: parseInt(sheetNum),
                scrapped_station: parseInt(stationNum)
            })
        });
        
        displayQueryResults(data, resultsDiv);
    } catch (error) {
        resultsDiv.innerHTML = `<p class="error">Error: ${error.message}</p>`;
    }
}

// ==================== Event Listeners ====================

/**
 * Setup event listeners on page load
 */
function setupEventListeners() {
    // Back buttons
    document.getElementById('back-to-projects').onclick = showProjectView;
    document.getElementById('back-to-workorders').onclick = () => {
        if (currentProject) {
            loadWorkOrders(currentProject.number, currentProject.name);
        }
    };
    
    // Close modals on outside click
    window.onclick = function(event) {
        if (event.target.classList.contains('modal')) {
            event.target.style.display = 'none';
        }
    };
}

// ==================== Initialize ====================

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    setupEventListeners();
    loadProjects();
});
