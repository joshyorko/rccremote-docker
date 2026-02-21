#!/bin/sh

# "internal" ZIPs are the artifacts from hololib builds in /robots.
# (whereas /hololib_zip are the imported ZIPs)
HOLOLIB_ZIP_PATH_INT=/hololib_zip_internal
HOLOLIB_ZIP_PATH=/hololib_zip
ROBOTS_PATH=/robots

if [ -z "$1" ]; then
    echo "Please provide the mode as an argument: rcc or rccremote."
    exit 1
fi

main() {
    # Check if the mode is rcc or rccremote
    if [ "$1" = "rcc" ]; then
        configure_rcc_client
    elif [ "$1" = "rccremote" ]; then
        start_rccremote
        #monitor_and_restart
    else
        echo "Invalid mode. Please provide either rcc or rccremote."
        exec tail -f /dev/null
    fi
}

disable_rcc_telemetry() {
    # Disable telemetry
    echo "Disabling telemetry..."
    rcc config identity -t
}

configure_rcc_client() {
    echo "=== MODE: rcc"
    disable_rcc_telemetry
    if [ -f /etc/certs/rootCA.pem ]; then
        echo "rootCA.pem found. Injecting into rcc-profile-ssl-cabundle.yaml..."

        # Export the content of rootCA.pem as an environment variable
        export ROOT_CA_CONTENT=$(cat /etc/certs/rootCA.pem)

        # Use envsubst to replace placeholders in the template with actual content
        envsubst '$ROOT_CA_CONTENT' </etc/rcc-profiles.d/rcc-profile-ssl-cabundle.yaml.template >/rcc-profile.yaml

        # indent any line after "ca-bundle" with two spaces
        sed -i '/ca-bundle/!b;n;:a;s/^/  /;n;ba' /rcc-profile.yaml

        import_and_switch_rcc_profile ssl-cabundle
    else
        cp /etc/rcc-profiles.d/rcc-profile-ssl-noverify.yaml /rcc-profile.yaml
        import_and_switch_rcc_profile ssl-noverify
    fi

    exec tail -f /dev/null
}

import_and_switch_rcc_profile() {
    PROFILE_NAME=$1
    rcc config import -f /rcc-profile.yaml
    rcc config switch -p $PROFILE_NAME
    echo "Switched to RCC profile $PROFILE_NAME."
}

start_rccremote() {
    echo "=== MODE: rccremote"
    disable_rcc_telemetry
    build_hololibs
    rcc_init
    import_hololib_zip_internal
    import_hololib_zip
    serve_hololibs

}

rcc_init() {
    echo "Enabling shared holotree..."
    rcc ht shared -e && rcc ht init
}

build_hololibs() {
    mkdir -p $HOLOLIB_ZIP_PATH_INT
    echo "###### Creating the hololibs: #####################################"
    find $ROBOTS_PATH -type f -name "robot.yaml" | while read -r robot_yaml; do
        robot=$(dirname "$robot_yaml")
        echo "Robot: $robot ------------------------------------------"
        # Check if conda.yaml exists in the same directory
        if [ -f "$robot/conda.yaml" ]; then
            echo "**** ROBOCORP_HOME: $ROBOCORP_HOME"
            if [ -f "$robot/.env" ]; then
                echo "  + Found .env file; sourcing it..."
                cat "$robot/.env"
                # Save the current environment variables to restore them later
                saved_env=$(mktemp)
                export -p >"$saved_env"
                set -a # (Export all variables sourced from the file)
                . "$robot/.env"
                set +a
            else
                echo "  - No .env file found; using default env."
            fi
            echo "  + Creating hololib for robot: $robot"
            echo "    BEGIN RCC LOG --- 8< ---"
            rcc ht vars -r "$robot_yaml"
            #rcc ht vars --timeline -r "$robot_yaml"
            echo "    END RCC LOG --- 8< ---"

            # export the hololib to a ZIP
            echo "  + Exporting hololib to ZIP ($HOLOLIB_ZIP_PATH_INT/$robot.zip)..."
            rcc ht export -r "$robot_yaml" -z "$HOLOLIB_ZIP_PATH_INT/$robot.zip"

            # if saved env exists, restore it
            if [ -f "$saved_env" ]; then
                unset ROBOCORP_HOME
                . "$saved_env" && rm "$saved_env"
            fi
        else
            echo "  - Skipping $robot: conda.yaml not found."
        fi

    done
}

import_hololib_zip_internal() {
    echo "Importing hololib ZIP artifacts from $HOLOLIB_ZIP_PATH_INT to shared holotree..."
    find $ROBOTS_PATH -type f -name "robot.yaml" | while read -r robot_yaml; do
        robot=$(dirname "$robot_yaml")
        if [ -f "$HOLOLIB_ZIP_PATH_INT/$robot.zip" ]; then
            echo "> importing Robot $robot from $HOLOLIB_ZIP_PATH_INT/$robot.zip..."
            rcc holotree import "$HOLOLIB_ZIP_PATH_INT/$robot.zip"
        else
            echo "WARNING! $HOLOLIB_ZIP_PATH_INT/$robot.zip not found."
        fi
    done
    print_catalogs
}

import_hololib_zip() {
    echo "Importing mounted hololib ZIP artifacts from $HOLOLIB_ZIP_PATH to shared holotree..."
    for zip in $HOLOLIB_ZIP_PATH/*.zip; do
        echo "> importing $zip ..."
        rcc holotree import "$zip"
    done
    print_catalogs
}

print_catalogs() {
    echo "Holotree catalogs:"
    echo "ROBOCORP_HOME: $ROBOCORP_HOME"
    rcc ht catalogs
    echo ""
}

serve_hololibs() {
    echo "Starting rccremote..."
    rccremote -hostname 0.0.0.0 -debug -trace
    # TODO: does not work
    #rccremote -hostname 0.0.0.0 -debug -trace & # Run in the background
    #RCCREMOTE_PID=$!                            # Capture the PID of rccremote
    #echo "rccremote started with PID: $RCCREMOTE_PID"
}

# monitor_and_restart() {
#     echo "--- Monitoring '$ROBOTS_PATH' for changes..."
#     while true; do
#         inotifywait -r -e modify,create,delete $ROBOTS_PATH
#         echo "!   Change detected in $ROBOTS_PATH. Restarting rccremote..."
#         if [ -n "$RCCREMOTE_PID" ]; then
#             kill "$RCCREMOTE_PID"
#             wait "$RCCREMOTE_PID" 2>/dev/null
#             echo "Stopped rccremote (PID: $RCCREMOTE_PID)"
#         fi
#         build_hololibs
#     done
# }

main "$@"
