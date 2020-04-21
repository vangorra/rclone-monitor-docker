#!/usr/bin/env bash
set -e

function showUsage() {
  cat <<EOF
usage: testrun.sh <config dir> <rclone destination>

EOF
}

CONFIG_DIR="$1"
RCLONE_DESTINATION="$2"
IMAGE_NAME="rclone-monitor-docker"
CONTAINER_NAME="rclone-monitor-docker"
TMP_MONITOR_DIR="/tmp/rclone-monitor-docker"

rm -rf "$TMP_MONITOR_DIR"
mkdir -p "$TMP_MONITOR_DIR"

if [[ -z "$CONFIG_DIR" ]]; then
  echo "Error: config directory required."
  showUsage
  exit 1
fi

if ! [[ -e "$CONFIG_DIR" ]]; then
  echo "Error '$CONFIG_DIR' does not exist."
  showUsage
  exit 1
fi

if ! [[ -d "$CONFIG_DIR" ]]; then
  echo "Error: '$CONFIG_DIR' is not a directory."
  showUsage
  exit 1
fi

if [[ -z "$RCLONE_DESTINATION" ]]; then
  echo "Error: Must provide an rclone destination."
  showUsage
  exit 1
fi

echo "Stopping and removing existing container"
docker ps -a --filter "name=$CONTAINER_NAME" --format "{{.ID}}" | xargs -r docker rm -f

echo "Building container"
docker build --tag "$IMAGE_NAME" .

echo "Starting new container."
docker run \
  --detach \
  --tty \
  --interactive \
  --name "$CONTAINER_NAME" \
  --volume "$CONFIG_DIR:/config" \
  --volume "$TMP_MONITOR_DIR:/files" \
  "$IMAGE_NAME" \
  --destination "$RCLONE_DESTINATION" \
  --unique-filenames

echo "Waiting to finish starting"
sleep 10

TEST_FILE="${TMP_MONITOR_DIR}/test_$(date '+%Y-%m-%dT%H:%M:%S').txt"
date > "$TEST_FILE"

echo "Waiting for changes."
sleep 10
docker logs --tail 50 "$CONTAINER_NAME"

echo "Stopping and removing existing container"
docker ps -a --filter "name=$CONTAINER_NAME" --format "{{.ID}}" | xargs -r docker rm -f
