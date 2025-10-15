#!/usr/bin/env python3
"""
RCC Remote Dashboard - Web UI for managing RCC Remote server
Provides a REST API and web interface for:
- Viewing system status and health
- Managing robot definitions
- Uploading/deleting robot files
- Viewing catalogs and holotree information
"""

import os
import json
import subprocess
import shutil
from pathlib import Path
from datetime import datetime
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from werkzeug.utils import secure_filename

app = Flask(__name__, static_folder='static', static_url_path='')
CORS(app)

# Configuration
ROBOTS_PATH = os.environ.get('ROBOTS_PATH', '/robots')
HOLOLIB_ZIP_PATH = os.environ.get('HOLOLIB_ZIP_PATH', '/hololib_zip')
RCCREMOTE_HOST = os.environ.get('RCCREMOTE_HOST', 'rccremote')
RCCREMOTE_PORT = os.environ.get('RCCREMOTE_PORT', '4653')
NGINX_HOST = os.environ.get('NGINX_HOST', 'nginx')

ALLOWED_EXTENSIONS = {'yaml', 'yml', 'zip', 'txt', 'py', 'robot', 'env'}

def allowed_file(filename):
    """Check if file extension is allowed"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def run_command(cmd, cwd=None):
    """Execute shell command and return output"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=30
        )
        return {
            'success': result.returncode == 0,
            'stdout': result.stdout,
            'stderr': result.stderr,
            'returncode': result.returncode
        }
    except subprocess.TimeoutExpired:
        return {
            'success': False,
            'stdout': '',
            'stderr': 'Command timeout',
            'returncode': -1
        }
    except Exception as e:
        return {
            'success': False,
            'stdout': '',
            'stderr': str(e),
            'returncode': -1
        }

# ============================================================================
# Health & Status Endpoints
# ============================================================================

@app.route('/api/health', methods=['GET'])
def health_check():
    """Basic health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'service': 'rcc-remote-dashboard'
    })

@app.route('/api/status', methods=['GET'])
def get_status():
    """Get comprehensive system status"""
    # Check if rccremote process is running
    rccremote_running = run_command('pgrep -x rccremote')['success']
    
    # Check nginx
    nginx_running = run_command('pgrep -x nginx')['success']
    
    # Get RCC version
    rcc_version = run_command('rcc --version')
    
    # Get catalog count
    catalogs_result = run_command('rcc holotree catalogs')
    catalog_lines = catalogs_result['stdout'].split('\n') if catalogs_result['success'] else []
    catalog_count = len([l for l in catalog_lines if l.strip() and not l.startswith('=')])
    
    # Get robot count
    robot_path = Path(ROBOTS_PATH)
    robot_count = len([d for d in robot_path.iterdir() if d.is_dir() and (d / 'robot.yaml').exists()])
    
    # Get hololib ZIP count
    hololib_path = Path(HOLOLIB_ZIP_PATH)
    zip_count = len(list(hololib_path.glob('*.zip'))) if hololib_path.exists() else 0
    
    return jsonify({
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'services': {
            'rccremote': {
                'running': rccremote_running,
                'host': RCCREMOTE_HOST,
                'port': RCCREMOTE_PORT
            },
            'nginx': {
                'running': nginx_running,
                'host': NGINX_HOST
            }
        },
        'rcc': {
            'version': rcc_version['stdout'].strip() if rcc_version['success'] else 'unknown',
            'available': rcc_version['success']
        },
        'statistics': {
            'robots': robot_count,
            'catalogs': catalog_count,
            'hololib_zips': zip_count
        },
        'paths': {
            'robots': ROBOTS_PATH,
            'hololib_zip': HOLOLIB_ZIP_PATH
        }
    })

@app.route('/api/catalogs', methods=['GET'])
def get_catalogs():
    """Get list of RCC holotree catalogs"""
    result = run_command('rcc holotree catalogs')
    
    if not result['success']:
        return jsonify({
            'error': 'Failed to retrieve catalogs',
            'details': result['stderr']
        }), 500
    
    # Parse catalog output
    catalogs = []
    for line in result['stdout'].split('\n'):
        line = line.strip()
        if line and not line.startswith('=') and not line.startswith('Holotree'):
            catalogs.append(line)
    
    return jsonify({
        'catalogs': catalogs,
        'count': len(catalogs),
        'raw_output': result['stdout']
    })

# ============================================================================
# Robot Management Endpoints
# ============================================================================

@app.route('/api/robots', methods=['GET'])
def get_robots():
    """List all robot directories"""
    robots_path = Path(ROBOTS_PATH)
    
    if not robots_path.exists():
        return jsonify({'error': 'Robots path does not exist'}), 404
    
    robots = []
    for robot_dir in sorted(robots_path.iterdir()):
        if robot_dir.is_dir():
            robot_yaml = robot_dir / 'robot.yaml'
            conda_yaml = robot_dir / 'conda.yaml'
            env_file = robot_dir / '.env'
            
            # Read conda.yaml to get dependencies info
            dependencies = []
            if conda_yaml.exists():
                try:
                    with open(conda_yaml, 'r') as f:
                        content = f.read()
                        # Simple parsing - count non-comment lines with content
                        for line in content.split('\n'):
                            line = line.strip()
                            if line and not line.startswith('#') and line.startswith('-'):
                                dependencies.append(line[1:].strip())
                except:
                    pass
            
            # Read .env if it exists
            robocorp_home = None
            if env_file.exists():
                try:
                    with open(env_file, 'r') as f:
                        for line in f:
                            if line.startswith('ROBOCORP_HOME='):
                                robocorp_home = line.split('=', 1)[1].strip()
                except:
                    pass
            
            robots.append({
                'name': robot_dir.name,
                'path': str(robot_dir),
                'has_robot_yaml': robot_yaml.exists(),
                'has_conda_yaml': conda_yaml.exists(),
                'has_env_file': env_file.exists(),
                'robocorp_home': robocorp_home,
                'dependencies_count': len(dependencies),
                'is_valid': robot_yaml.exists() and conda_yaml.exists()
            })
    
    return jsonify({
        'robots': robots,
        'count': len(robots)
    })

@app.route('/api/robots/<robot_name>', methods=['GET'])
def get_robot(robot_name):
    """Get details of a specific robot"""
    robot_name = secure_filename(robot_name)
    robot_path = Path(ROBOTS_PATH) / robot_name
    
    if not robot_path.exists():
        return jsonify({'error': 'Robot not found'}), 404
    
    files = {}
    for file_name in ['robot.yaml', 'conda.yaml', '.env']:
        file_path = robot_path / file_name
        if file_path.exists():
            try:
                with open(file_path, 'r') as f:
                    files[file_name] = f.read()
            except Exception as e:
                files[file_name] = f"Error reading file: {str(e)}"
    
    # Get all files in robot directory
    all_files = []
    for item in robot_path.rglob('*'):
        if item.is_file():
            rel_path = item.relative_to(robot_path)
            all_files.append(str(rel_path))
    
    return jsonify({
        'name': robot_name,
        'path': str(robot_path),
        'files': files,
        'all_files': sorted(all_files)
    })

@app.route('/api/robots/<robot_name>/files/<path:filename>', methods=['GET'])
def get_robot_file(robot_name, filename):
    """Get contents of a specific robot file"""
    robot_name = secure_filename(robot_name)
    filename = secure_filename(filename)
    
    file_path = Path(ROBOTS_PATH) / robot_name / filename
    
    if not file_path.exists():
        return jsonify({'error': 'File not found'}), 404
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        return jsonify({
            'filename': filename,
            'content': content
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/robots', methods=['POST'])
def create_robot():
    """Create a new robot directory"""
    data = request.get_json()
    robot_name = data.get('name')
    
    if not robot_name:
        return jsonify({'error': 'Robot name is required'}), 400
    
    robot_name = secure_filename(robot_name)
    robot_path = Path(ROBOTS_PATH) / robot_name
    
    if robot_path.exists():
        return jsonify({'error': 'Robot already exists'}), 409
    
    try:
        robot_path.mkdir(parents=True, exist_ok=True)
        
        # Create default robot.yaml
        robot_yaml_content = """# Robot configuration
tasks:
  Default:
    shell: python -m robot --report NONE --outputdir output --logtitle "Task log" tasks.robot

environmentConfigs:
  - conda.yaml

artifactsDir: output

PATH:
  - .
PYTHONPATH:
  - .
"""
        with open(robot_path / 'robot.yaml', 'w') as f:
            f.write(robot_yaml_content)
        
        # Create default conda.yaml
        conda_yaml_content = """channels:
  - conda-forge

dependencies:
  - python>=3.12
  - pip:
    - robotframework==7.3.2
"""
        with open(robot_path / 'conda.yaml', 'w') as f:
            f.write(conda_yaml_content)
        
        return jsonify({
            'message': 'Robot created successfully',
            'name': robot_name,
            'path': str(robot_path)
        }), 201
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/robots/<robot_name>', methods=['DELETE'])
def delete_robot(robot_name):
    """Delete a robot directory"""
    robot_name = secure_filename(robot_name)
    robot_path = Path(ROBOTS_PATH) / robot_name
    
    if not robot_path.exists():
        return jsonify({'error': 'Robot not found'}), 404
    
    try:
        shutil.rmtree(robot_path)
        return jsonify({
            'message': 'Robot deleted successfully',
            'name': robot_name
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/robots/<robot_name>/upload', methods=['POST'])
def upload_robot_files(robot_name):
    """Upload files to a robot directory"""
    robot_name = secure_filename(robot_name)
    robot_path = Path(ROBOTS_PATH) / robot_name
    
    if not robot_path.exists():
        robot_path.mkdir(parents=True, exist_ok=True)
    
    if 'files' not in request.files:
        return jsonify({'error': 'No files provided'}), 400
    
    files = request.files.getlist('files')
    uploaded = []
    errors = []
    
    for file in files:
        if file and file.filename:
            filename = secure_filename(file.filename)
            
            if not allowed_file(filename):
                errors.append(f'{filename}: File type not allowed')
                continue
            
            try:
                file_path = robot_path / filename
                file.save(file_path)
                uploaded.append(filename)
            except Exception as e:
                errors.append(f'{filename}: {str(e)}')
    
    return jsonify({
        'message': f'Uploaded {len(uploaded)} file(s)',
        'uploaded': uploaded,
        'errors': errors
    })

# ============================================================================
# Hololib ZIP Management
# ============================================================================

@app.route('/api/hololib-zips', methods=['GET'])
def get_hololib_zips():
    """List all hololib ZIP files"""
    hololib_path = Path(HOLOLIB_ZIP_PATH)
    
    if not hololib_path.exists():
        return jsonify({'zips': [], 'count': 0})
    
    zips = []
    for zip_file in sorted(hololib_path.glob('*.zip')):
        stat = zip_file.stat()
        zips.append({
            'name': zip_file.name,
            'size': stat.st_size,
            'size_mb': round(stat.st_size / (1024 * 1024), 2),
            'modified': datetime.fromtimestamp(stat.st_mtime).isoformat()
        })
    
    return jsonify({
        'zips': zips,
        'count': len(zips)
    })

@app.route('/api/hololib-zips/upload', methods=['POST'])
def upload_hololib_zip():
    """Upload hololib ZIP file"""
    if 'file' not in request.files:
        return jsonify({'error': 'No file provided'}), 400
    
    file = request.files['file']
    
    if file.filename == '':
        return jsonify({'error': 'No file selected'}), 400
    
    if not file.filename.endswith('.zip'):
        return jsonify({'error': 'Only ZIP files are allowed'}), 400
    
    filename = secure_filename(file.filename)
    file_path = Path(HOLOLIB_ZIP_PATH) / filename
    
    try:
        file.save(file_path)
        return jsonify({
            'message': 'ZIP file uploaded successfully',
            'filename': filename
        }), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/hololib-zips/<filename>', methods=['DELETE'])
def delete_hololib_zip(filename):
    """Delete a hololib ZIP file"""
    filename = secure_filename(filename)
    file_path = Path(HOLOLIB_ZIP_PATH) / filename
    
    if not file_path.exists():
        return jsonify({'error': 'File not found'}), 404
    
    try:
        file_path.unlink()
        return jsonify({
            'message': 'ZIP file deleted successfully',
            'filename': filename
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ============================================================================
# Static Files & Frontend
# ============================================================================

@app.route('/')
def index():
    """Serve the main UI"""
    return send_from_directory('static', 'index.html')

@app.route('/<path:path>')
def static_files(path):
    """Serve static files"""
    return send_from_directory('static', path)

# ============================================================================
# Main
# ============================================================================

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('DEBUG', 'false').lower() == 'true'
    
    print(f"""
╔════════════════════════════════════════════════════════════╗
║  RCC Remote Dashboard                                      ║
║  Web UI for RCC Remote Management                          ║
╚════════════════════════════════════════════════════════════╝

→ API Server: http://0.0.0.0:{port}
→ Robots Path: {ROBOTS_PATH}
→ Hololib Path: {HOLOLIB_ZIP_PATH}
→ RCC Remote: {RCCREMOTE_HOST}:{RCCREMOTE_PORT}

Ready to serve...
""")
    
    app.run(host='0.0.0.0', port=port, debug=debug)
