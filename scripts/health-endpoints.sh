#!/bin/sh

# Health endpoint server wrapper for RCC Remote
# Provides /health/live, /health/ready, /health/startup, and /metrics endpoints

set -e

HEALTH_PORT="${HEALTH_PORT:-4654}"
RCCREMOTE_PORT="${RCCREMOTE_PORT:-4653}"
LOG_FILE="/tmp/rccremote-health.log"
START_TIME=$(date +%s)

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if rccremote process is running
check_rccremote_process() {
    if pgrep -x rccremote >/dev/null 2>&1; then
        echo "pass"
    else
        echo "fail"
    fi
}

# Check if rccremote is responding
check_rccremote_ready() {
    if nc -z localhost "$RCCREMOTE_PORT" 2>/dev/null; then
        echo "pass"
    else
        echo "fail"
    fi
}

# Check holotree availability
check_holotree() {
    if [ -d "$ROBOCORP_HOME" ]; then
        echo "pass"
    else
        echo "fail"
    fi
}

# Check SSL certificates
check_ssl_certs() {
    if [ -f "/etc/certs/server.crt" ] && [ -f "/etc/certs/server.key" ]; then
        echo "pass"
    else
        echo "warn"
    fi
}

# Get uptime in seconds
get_uptime() {
    local now=$(date +%s)
    echo $((now - START_TIME))
}

# Generate health response
generate_health_response() {
    local probe_type=$1
    local rccremote_status=$(check_rccremote_process)
    local ready_status=$(check_rccremote_ready)
    local holotree_status=$(check_holotree)
    local ssl_status=$(check_ssl_certs)
    local uptime=$(get_uptime)
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Determine overall status
    local overall_status="healthy"
    local http_code=200
    
    if [ "$probe_type" = "startup" ]; then
        # Startup probe checks if initialization is complete
        if [ "$ready_status" = "pass" ] && [ $uptime -gt 10 ]; then
            overall_status="healthy"
            http_code=200
        else
            overall_status="starting"
            http_code=503
        fi
    elif [ "$probe_type" = "ready" ]; then
        # Readiness probe checks if service can accept traffic
        if [ "$rccremote_status" = "pass" ] && [ "$ready_status" = "pass" ]; then
            overall_status="healthy"
            http_code=200
        else
            overall_status="unhealthy"
            http_code=503
        fi
    else  # liveness
        # Liveness probe checks if service is alive
        if [ "$rccremote_status" = "pass" ]; then
            overall_status="healthy"
            http_code=200
        else
            overall_status="unhealthy"
            http_code=500
        fi
    fi
    
    # Generate JSON response
    cat <<EOF
HTTP/1.1 $http_code OK
Content-Type: application/json
Connection: close

{
  "status": "$overall_status",
  "timestamp": "$timestamp",
  "checks": {
    "rccremote_process": {
      "status": "$rccremote_status",
      "message": "RCC Remote process $([ "$rccremote_status" = "pass" ] && echo "is running" || echo "is not running")"
    },
    "holotree_available": {
      "status": "$holotree_status",
      "message": "Holotree directory $([ "$holotree_status" = "pass" ] && echo "exists" || echo "missing")"
    },
    "ssl_certificates": {
      "status": "$ssl_status",
      "message": "SSL certificates $([ "$ssl_status" = "pass" ] && echo "found" || echo "not found or warning")"
    }
  },
  "uptime_seconds": $uptime
}
EOF
}

# Generate Prometheus metrics
generate_metrics() {
    local uptime=$(get_uptime)
    local rccremote_status=$(check_rccremote_process)
    local process_running=$([ "$rccremote_status" = "pass" ] && echo "1" || echo "0")
    
    cat <<EOF
HTTP/1.1 200 OK
Content-Type: text/plain
Connection: close

# HELP rccremote_up RCC Remote service is up (1) or down (0)
# TYPE rccremote_up gauge
rccremote_up $process_running

# HELP rccremote_uptime_seconds RCC Remote service uptime in seconds
# TYPE rccremote_uptime_seconds counter
rccremote_uptime_seconds $uptime

# HELP rccremote_health_checks Health check status (1 = pass, 0 = fail)
# TYPE rccremote_health_checks gauge
rccremote_health_checks{check="process"} $process_running
EOF
}

# Simple HTTP server to handle health requests
handle_request() {
    local request=$(head -n 1)
    local path=$(echo "$request" | cut -d' ' -f2)
    
    case "$path" in
        /health/live)
            generate_health_response "live"
            ;;
        /health/ready)
            generate_health_response "ready"
            ;;
        /health/startup)
            generate_health_response "startup"
            ;;
        /metrics)
            generate_metrics
            ;;
        *)
            cat <<EOF
HTTP/1.1 404 Not Found
Content-Type: application/json
Connection: close

{"error": "Not Found", "path": "$path"}
EOF
            ;;
    esac
}

# Start health endpoint server
start_health_server() {
    log "Starting health endpoint server on port $HEALTH_PORT"
    
    while true; do
        nc -l -p "$HEALTH_PORT" -q 1 < <(handle_request) 2>/dev/null || true
    done
}

# Main
log "Health endpoint wrapper starting..."
log "RCC Remote expected on port: $RCCREMOTE_PORT"
log "Health endpoints on port: $HEALTH_PORT"

# Start health server in background
start_health_server &
HEALTH_PID=$!

log "Health endpoint server started (PID: $HEALTH_PID)"
log "Available endpoints:"
log "  - http://localhost:$HEALTH_PORT/health/live"
log "  - http://localhost:$HEALTH_PORT/health/ready"
log "  - http://localhost:$HEALTH_PORT/health/startup"
log "  - http://localhost:$HEALTH_PORT/metrics"

# Keep script running
wait $HEALTH_PID
