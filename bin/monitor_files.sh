#!/usr/bin/env bash
set -e

RCLONE_FILE_HASH_LENGTH="4"
RETRY_COUNT="6"
BASE_STAGING_DIR="/tmp/monitor_files_staging"
RCLONE_CONFIG_FILE="/config/rclone.conf"

function errorMsg() {
  echo "ERROR: $@"
}

function coalesce() {
  if [[ -n "$1" ]]; then
    echo "$1"
  elif [[ -n "$2" ]]; then
    echo "$2"
  fi
}

function showUsage() {
  cat << EOF
usage:
  --destination       The destination to copy the files. (required)
  --unique-filenames  Makes all file names unique when uploading.
EOF
}

UNIQUE_FILENAMES="0"
while [[ "$#" -gt 0 ]]
do
  key="$1"
  case "$key" in
    --destination)
      RCLONE_DESTINATION="$2"
      shift
      shift
    ;;
    --unique-filenames)
      UNIQUE_FILENAMES="1"
      shift
      ;;
    *)
      shift # past argument
    ;;
  esac
done

if ! [[ -e "$RCLONE_CONFIG_FILE" ]]; then
  errorMsg "'$RCLONE_CONFIG_FILE' does not exist. You need to map it with --volume <hostpath to config dir>:/config. Or you need to configure rclone."
  exit 1
fi

if [[ -z "$RCLONE_DESTINATION" ]]; then
  errorMsg "Destination was not provided."
  showUsage
  exit 1
fi

# Verify config section in rclone.conf exists for destination provided.
RCLONE_CONFIG_SECTION_NAME=$(echo "$RCLONE_DESTINATION" | sed -E 's/:.*//')
if [[ $(grep -c "\[$RCLONE_CONFIG_SECTION_NAME\]" "$RCLONE_CONFIG_FILE") != "1" ]]; then
  errorMsg "Could not find a config section named '$RCLONE_CONFIG_SECTION_NAME' in rclone.conf."
  exit 1
fi


echo `date`
echo "Watching /files for changes."
inotifywait -q --monitor --event close_write,moved_to --format '%w%f' "/files/" | while read FILE_PATH
do
  if ! [[ -f "$FILE_PATH" ]]; then
    continue
  fi

  echo ""
  echo "File creation detected."
  for i in $(seq 1 "$RETRY_COUNT")
  do
    echo "($i / $RETRY_COUNT) Attempting copy of $FILE_PATH"

    FILE_EXT=$(basename "$FILE_PATH" | sed -E 's/.*\.([a-zA-Z0-9]+)$/\1/')
    FILE_NAME=$(basename "$FILE_PATH" | sed -E 's/\.[a-zA-Z0-9]+$//')

    if [[ "$UNIQUE_FILENAMES" = "1" ]]; then
      FILE_HASH=$(md5sum "$FILE_PATH" | cut -d ' ' -f1 | head -c "$RCLONE_FILE_HASH_LENGTH")
      STAGING_DIR="$BASE_STAGING_DIR/$FILE_HASH"
      STAGING_FILE_PATH="$STAGING_DIR/$FILE_NAME.$FILE_HASH.$FILE_EXT"
    else
      STAGING_DIR="$BASE_STAGING_DIR"
      STAGING_FILE_PATH="$STAGING_DIR/$FILE_NAME.$FILE_EXT"
    fi

    echo "Copying '$FILE_PATH' to staging '$STAGING_FILE_PATH'."
    mkdir -p "$STAGING_DIR"
    cp "$FILE_PATH" "$STAGING_FILE_PATH"

    echo "Copying '$STAGING_FILE_PATH' to '$RCLONE_DESTINATION'"
    rclone --retries 1 --config /config/rclone.conf copy "$STAGING_FILE_PATH" "$RCLONE_DESTINATION"
    if [[ "$?" = "0" ]]; then
      echo "Copy successful, removing temp files."
      rm "$FILE_PATH"
      rm -rf "$STAGING_DIR"
      break;
    fi

    if [[ "$i" < "$RETRY_COUNT" ]]; then
      echo "Copy failed, retrying in 5 seconds."
      sleep 5
    else
      echo "Copy failed. Will not retry."
    fi
   done
done
