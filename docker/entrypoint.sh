#!/bin/sh

# start app instance in foreground
start_app() {
  if [[ "$DEBUG" = "true" ]]; then
    echo $(ls -l /app/$APP_NAME)
    /app/dlv --listen=:$DEBUG_PORT --headless=true --api-version=2 --accept-multiclient --log exec /app/${APP_NAME}
  else
    /app/${APP_NAME}
  fi
}

# parsing arguments from command line
process_args() {
  while [[ $# -gt 0 ]]; do
      case "$1" in
      -o|--port)         APP_PORT=$2 && shift 2 ;;
      -h|--db-host)       DB_HOST=$2 && shift 2 ;;
      -t|--db-port)       DB_PORT=$2 && shift 2 ;;
      -u|--db-user)       DB_USER=$2 && shift 2 ;;
      -p|--db-pass)       DB_PASS=$2 && shift 2 ;;
      -n|--db-name)       DB_NAME=$2 && shift 2 ;;
      -d|--debug)           DEBUG=$2 && shift 2 ;;
      -x|--debug-port) DEBUG_PORT=$2 && shift 2 ;;
      --app)             APP_NAME=$2 && shift 2 ;;
      *) ;;
      esac
  done
  DB_URL="jdbc:mysql://$DB_HOST:$DB_PORT/$DB_NAME"
}

## ----------------------------------------------------- ##
# load secrets
if [[ ! -d /run/secret/${APP_NAME}-* ]]; then
  IOH_DB_PASS=${IOH_DB_PASS:-`cat /run/secret/${APP_NAME}-db-pass`}
fi

# setup defaults
APP_NAME=iohub-stories
APP_PORT=${IOH_SERVER_ADDR:-"9001"}
DB_URL=""
DB_HOST=${IOH_DB_HOST:-""}
DB_PORT=${IOH_DB_PORT:-""}
DB_NAME=${IOH_DB_NAME:-""}
DB_USER=${IOH_DB_USER:-""}
DB_PASS=${IOH_DB_PASS:-""}
DEBUG=false
DEBUG_PORT=40000

# arguments setup
echo "Starting Service..."
process_args "$@"

# wait when DB configuration exists
if [[ ! -z ${DB_NAME} ]] && [[ ! -z ${DB_USER} ]] && [[ ! -z ${DB_PASS} ]]; then
  echo "Waitting for database..."
  # test db server before start
  /app/wait-for-it.sh $(echo ${DB_URL} | awk -F/ '{print $3}') -t 0
fi

# start app anyway
start_app
