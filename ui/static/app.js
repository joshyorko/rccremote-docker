// RCC Remote Dashboard - Application Logic

const API_BASE = window.location.origin;

// State
let state = {
    robots: [],
    catalogs: [],
    zips: [],
    status: null,
    selectedRobot: null
};

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    initTabs();
    initUploadZones();
    initAutoRefresh();
    loadDashboard();
});

// ============================================================================
// Tab Management
// ============================================================================

function initTabs() {
    const tabs = document.querySelectorAll('.tab');
    tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            const targetTab = tab.dataset.tab;
            switchTab(targetTab);
        });
    });
}

function switchTab(tabName) {
    // Update tab buttons
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');
    
    // Update tab content
    document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
    document.getElementById(tabName).classList.add('active');
    
    // Load data for the active tab
    if (tabName === 'robots') {
        loadRobots();
    } else if (tabName === 'catalogs') {
        loadCatalogs();
    } else if (tabName === 'zips') {
        loadZips();
    }
}

// ============================================================================
// Dashboard & Status
// ============================================================================

async function loadDashboard() {
    try {
        const response = await fetch(`${API_BASE}/api/status`);
        const data = await response.json();
        state.status = data;
        
        updateStatusIndicators(data);
        updateStatusDisplay(data);
        loadRobots(); // Load initial content
    } catch (error) {
        console.error('Failed to load dashboard:', error);
        showToast('Failed to connect to server', 'error');
        updateConnectionStatus(false);
    }
}

function updateConnectionStatus(isOnline) {
    const statusIndicator = document.getElementById('connectionStatus');
    const statusText = document.getElementById('statusText');
    
    if (isOnline) {
        statusIndicator.classList.add('online');
        statusIndicator.classList.remove('offline');
        statusText.textContent = 'ONLINE';
    } else {
        statusIndicator.classList.remove('online');
        statusIndicator.classList.add('offline');
        statusText.textContent = 'OFFLINE';
    }
}

function updateStatusDisplay(data) {
    const rccremoteStatus = document.getElementById('rccremoteStatus');
    const nginxStatus = document.getElementById('nginxStatus');
    
    rccremoteStatus.textContent = data.services.rccremote.running ? 'RUNNING' : 'STOPPED';
    rccremoteStatus.className = `stat-value ${data.services.rccremote.running ? 'status-running' : 'status-stopped'}`;
    
    nginxStatus.textContent = data.services.nginx.running ? 'RUNNING' : 'STOPPED';
    nginxStatus.className = `stat-value ${data.services.nginx.running ? 'status-running' : 'status-stopped'}`;
    
    document.getElementById('robotCount').textContent = data.statistics.robots;
    document.getElementById('catalogCount').textContent = data.statistics.catalogs;
    document.getElementById('zipCount').textContent = data.statistics.hololib_zips;
    document.getElementById('rccVersion').textContent = data.rcc.version || 'N/A';
    
    updateConnectionStatus(true);
}

function updateStatusIndicators(data) {
    // Update any additional status indicators
}

// ============================================================================
// Robots Management
// ============================================================================

async function loadRobots() {
    showLoading();
    try {
        const response = await fetch(`${API_BASE}/api/robots`);
        const data = await response.json();
        state.robots = data.robots;
        renderRobots(data.robots);
    } catch (error) {
        console.error('Failed to load robots:', error);
        showToast('Failed to load robots', 'error');
    } finally {
        hideLoading();
    }
}

function renderRobots(robots) {
    const container = document.getElementById('robotsList');
    
    if (robots.length === 0) {
        container.innerHTML = `
            <div class="terminal-output" style="text-align: center; padding: 2rem;">
                No robots found. Create one or upload robot files.
            </div>
        `;
        return;
    }
    
    container.innerHTML = robots.map(robot => `
        <div class="robot-item ${robot.is_valid ? 'valid' : 'invalid'}">
            <div class="robot-header">
                <div class="robot-name">${robot.name}</div>
                <div class="robot-actions">
                    <button class="btn btn-small btn-secondary" onclick="viewRobotDetails('${robot.name}')">VIEW</button>
                    <button class="btn btn-small btn-primary" onclick="selectRobotForUpload('${robot.name}')">UPLOAD</button>
                    <button class="btn btn-small btn-danger" onclick="deleteRobot('${robot.name}')">DELETE</button>
                </div>
            </div>
            <div class="robot-meta">
                <span>
                    <span class="robot-badge ${robot.has_robot_yaml ? 'success' : 'warning'}">
                        robot.yaml ${robot.has_robot_yaml ? '✓' : '✗'}
                    </span>
                </span>
                <span>
                    <span class="robot-badge ${robot.has_conda_yaml ? 'success' : 'warning'}">
                        conda.yaml ${robot.has_conda_yaml ? '✓' : '✗'}
                    </span>
                </span>
                ${robot.has_env_file ? '<span class="robot-badge success">.env ✓</span>' : ''}
                ${robot.robocorp_home ? `<span>HOME: ${robot.robocorp_home}</span>` : ''}
                ${robot.dependencies_count > 0 ? `<span>${robot.dependencies_count} dependencies</span>` : ''}
            </div>
        </div>
    `).join('');
}

function showCreateRobotModal() {
    document.getElementById('createRobotModal').classList.add('active');
    document.getElementById('robotName').value = '';
    document.getElementById('robotName').focus();
}

function closeCreateRobotModal() {
    document.getElementById('createRobotModal').classList.remove('active');
}

async function createRobot() {
    const name = document.getElementById('robotName').value.trim();
    
    if (!name) {
        showToast('Please enter a robot name', 'warning');
        return;
    }
    
    if (!/^[a-z0-9-]+$/.test(name)) {
        showToast('Robot name must contain only lowercase letters, numbers, and hyphens', 'warning');
        return;
    }
    
    showLoading();
    try {
        const response = await fetch(`${API_BASE}/api/robots`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name })
        });
        
        if (response.ok) {
            showToast(`Robot "${name}" created successfully`, 'success');
            closeCreateRobotModal();
            loadRobots();
            loadDashboard(); // Refresh stats
        } else {
            const error = await response.json();
            showToast(error.error || 'Failed to create robot', 'error');
        }
    } catch (error) {
        console.error('Failed to create robot:', error);
        showToast('Failed to create robot', 'error');
    } finally {
        hideLoading();
    }
}

async function deleteRobot(name) {
    if (!confirm(`Are you sure you want to delete robot "${name}"?\n\nThis action cannot be undone.`)) {
        return;
    }
    
    showLoading();
    try {
        const response = await fetch(`${API_BASE}/api/robots/${name}`, {
            method: 'DELETE'
        });
        
        if (response.ok) {
            showToast(`Robot "${name}" deleted successfully`, 'success');
            loadRobots();
            loadDashboard(); // Refresh stats
        } else {
            const error = await response.json();
            showToast(error.error || 'Failed to delete robot', 'error');
        }
    } catch (error) {
        console.error('Failed to delete robot:', error);
        showToast('Failed to delete robot', 'error');
    } finally {
        hideLoading();
    }
}

async function viewRobotDetails(name) {
    showLoading();
    try {
        const response = await fetch(`${API_BASE}/api/robots/${name}`);
        const robot = await response.json();
        
        let content = `<div class="robot-details">`;
        content += `<p><strong>Path:</strong> <code>${robot.path}</code></p>`;
        content += `<p><strong>Files:</strong> ${robot.all_files.length}</p>`;
        
        // Show file contents
        for (const [filename, fileContent] of Object.entries(robot.files)) {
            content += `
                <h4 style="color: var(--accent-secondary); margin-top: 1.5rem;">${filename}</h4>
                <div class="code-block">
                    <pre>${escapeHtml(fileContent)}</pre>
                </div>
            `;
        }
        
        // List all files
        if (robot.all_files.length > 0) {
            content += `
                <h4 style="color: var(--accent-secondary); margin-top: 1.5rem;">All Files</h4>
                <div class="terminal-output">
${robot.all_files.map(f => `  ${f}`).join('\n')}
                </div>
            `;
        }
        
        content += `</div>`;
        
        document.getElementById('robotDetailsTitle').textContent = `> ROBOT: ${name}`;
        document.getElementById('robotDetailsContent').innerHTML = content;
        document.getElementById('robotDetailsModal').classList.add('active');
    } catch (error) {
        console.error('Failed to load robot details:', error);
        showToast('Failed to load robot details', 'error');
    } finally {
        hideLoading();
    }
}

function closeRobotDetailsModal() {
    document.getElementById('robotDetailsModal').classList.remove('active');
}

// ============================================================================
// File Upload
// ============================================================================

function initUploadZones() {
    // Robot upload zone
    const robotUploadZone = document.getElementById('robotUploadZone');
    const robotFileInput = document.getElementById('robotFileInput');
    
    robotUploadZone.addEventListener('click', () => {
        if (!state.selectedRobot) {
            showToast('Please select a robot first or create a new one', 'info');
            return;
        }
        robotFileInput.click();
    });
    
    robotFileInput.addEventListener('change', (e) => {
        if (state.selectedRobot) {
            uploadRobotFiles(state.selectedRobot, e.target.files);
        }
    });
    
    setupDragAndDrop(robotUploadZone, (files) => {
        if (!state.selectedRobot) {
            showToast('Please select a robot first', 'warning');
            return;
        }
        uploadRobotFiles(state.selectedRobot, files);
    });
    
    // ZIP upload zone
    const zipUploadZone = document.getElementById('zipUploadZone');
    const zipFileInput = document.getElementById('zipFileInput');
    
    zipUploadZone.addEventListener('click', () => zipFileInput.click());
    zipFileInput.addEventListener('change', (e) => {
        if (e.target.files.length > 0) {
            uploadZipFile(e.target.files[0]);
        }
    });
    
    setupDragAndDrop(zipUploadZone, (files) => {
        if (files.length > 0 && files[0].name.endsWith('.zip')) {
            uploadZipFile(files[0]);
        } else {
            showToast('Please drop a ZIP file', 'warning');
        }
    });
}

function setupDragAndDrop(element, onDrop) {
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        element.addEventListener(eventName, preventDefaults, false);
    });
    
    function preventDefaults(e) {
        e.preventDefault();
        e.stopPropagation();
    }
    
    ['dragenter', 'dragover'].forEach(eventName => {
        element.addEventListener(eventName, () => {
            element.classList.add('dragover');
        }, false);
    });
    
    ['dragleave', 'drop'].forEach(eventName => {
        element.addEventListener(eventName, () => {
            element.classList.remove('dragover');
        }, false);
    });
    
    element.addEventListener('drop', (e) => {
        const files = Array.from(e.dataTransfer.files);
        onDrop(files);
    }, false);
}

function selectRobotForUpload(robotName) {
    state.selectedRobot = robotName;
    showToast(`Robot "${robotName}" selected. You can now upload files.`, 'info');
    document.getElementById('robotFileInput').click();
}

async function uploadRobotFiles(robotName, files) {
    const formData = new FormData();
    Array.from(files).forEach(file => {
        formData.append('files', file);
    });
    
    showLoading();
    try {
        const response = await fetch(`${API_BASE}/api/robots/${robotName}/upload`, {
            method: 'POST',
            body: formData
        });
        
        const result = await response.json();
        
        if (result.uploaded && result.uploaded.length > 0) {
            showToast(`Uploaded ${result.uploaded.length} file(s) to ${robotName}`, 'success');
            loadRobots();
        }
        
        if (result.errors && result.errors.length > 0) {
            result.errors.forEach(error => {
                showToast(error, 'error');
            });
        }
    } catch (error) {
        console.error('Failed to upload files:', error);
        showToast('Failed to upload files', 'error');
    } finally {
        hideLoading();
        state.selectedRobot = null;
    }
}

// ============================================================================
// Catalogs Management
// ============================================================================

async function loadCatalogs() {
    showLoading();
    try {
        const response = await fetch(`${API_BASE}/api/catalogs`);
        const data = await response.json();
        state.catalogs = data.catalogs;
        renderCatalogs(data);
    } catch (error) {
        console.error('Failed to load catalogs:', error);
        showToast('Failed to load catalogs', 'error');
    } finally {
        hideLoading();
    }
}

function renderCatalogs(data) {
    const output = document.getElementById('catalogsOutput');
    
    if (data.catalogs.length === 0) {
        output.textContent = 'No catalogs found.\n\nAdd robots or import ZIP files to create catalogs.';
    } else {
        output.textContent = `Found ${data.count} catalog(s):\n\n` + data.raw_output;
    }
}

function refreshCatalogs() {
    loadCatalogs();
    showToast('Refreshing catalogs...', 'info');
}

// ============================================================================
// Hololib ZIPs Management
// ============================================================================

async function loadZips() {
    showLoading();
    try {
        const response = await fetch(`${API_BASE}/api/hololib-zips`);
        const data = await response.json();
        state.zips = data.zips;
        renderZips(data.zips);
    } catch (error) {
        console.error('Failed to load ZIP files:', error);
        showToast('Failed to load ZIP files', 'error');
    } finally {
        hideLoading();
    }
}

function renderZips(zips) {
    const container = document.getElementById('zipsList');
    
    if (zips.length === 0) {
        container.innerHTML = `
            <div class="terminal-output" style="text-align: center; padding: 2rem;">
                No ZIP files found. Upload pre-built catalog archives.
            </div>
        `;
        return;
    }
    
    container.innerHTML = zips.map(zip => `
        <div class="zip-item">
            <div class="zip-info">
                <div class="zip-name">${zip.name}</div>
                <div class="zip-meta">
                    Size: ${zip.size_mb} MB | Modified: ${formatDate(zip.modified)}
                </div>
            </div>
            <button class="btn btn-small btn-danger" onclick="deleteZip('${zip.name}')">DELETE</button>
        </div>
    `).join('');
}

async function uploadZipFile(file) {
    const formData = new FormData();
    formData.append('file', file);
    
    showLoading();
    try {
        const response = await fetch(`${API_BASE}/api/hololib-zips/upload`, {
            method: 'POST',
            body: formData
        });
        
        if (response.ok) {
            showToast(`ZIP file "${file.name}" uploaded successfully`, 'success');
            loadZips();
            loadDashboard(); // Refresh stats
        } else {
            const error = await response.json();
            showToast(error.error || 'Failed to upload ZIP file', 'error');
        }
    } catch (error) {
        console.error('Failed to upload ZIP file:', error);
        showToast('Failed to upload ZIP file', 'error');
    } finally {
        hideLoading();
    }
}

async function deleteZip(filename) {
    if (!confirm(`Are you sure you want to delete "${filename}"?`)) {
        return;
    }
    
    showLoading();
    try {
        const response = await fetch(`${API_BASE}/api/hololib-zips/${filename}`, {
            method: 'DELETE'
        });
        
        if (response.ok) {
            showToast(`ZIP file "${filename}" deleted successfully`, 'success');
            loadZips();
            loadDashboard(); // Refresh stats
        } else {
            const error = await response.json();
            showToast(error.error || 'Failed to delete ZIP file', 'error');
        }
    } catch (error) {
        console.error('Failed to delete ZIP file:', error);
        showToast('Failed to delete ZIP file', 'error');
    } finally {
        hideLoading();
    }
}

// ============================================================================
// UI Utilities
// ============================================================================

function showToast(message, type = 'info') {
    const container = document.getElementById('toastContainer');
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = message;
    
    container.appendChild(toast);
    
    setTimeout(() => {
        toast.style.animation = 'slideIn 0.3s ease reverse';
        setTimeout(() => toast.remove(), 300);
    }, 5000);
}

function showLoading() {
    document.getElementById('loadingOverlay').classList.add('active');
}

function hideLoading() {
    document.getElementById('loadingOverlay').classList.remove('active');
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function formatDate(isoDate) {
    const date = new Date(isoDate);
    return date.toLocaleString();
}

// ============================================================================
// Auto Refresh
// ============================================================================

function initAutoRefresh() {
    // Refresh dashboard every 10 seconds
    setInterval(() => {
        loadDashboard();
    }, 10000);
}

// Keyboard shortcuts
document.addEventListener('keydown', (e) => {
    // ESC to close modals
    if (e.key === 'Escape') {
        closeCreateRobotModal();
        closeRobotDetailsModal();
    }
    
    // Ctrl/Cmd + N to create new robot
    if ((e.ctrlKey || e.metaKey) && e.key === 'n') {
        e.preventDefault();
        showCreateRobotModal();
    }
});
