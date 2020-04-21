# rclone-monitor-docker
Monitors a directory for changes and moves those files with rclone.

## Quickstart
- Get and configure rclone for your preferred cloud provider.
- Launch the container
```
docker run \
  --name rclone-monitor \
  --volume /path/to/rclone/config/dir:/config \
  --volume /path/to/directory/to/monitor:/files \
  vangorra/rclone-monitor-docker \
  --destination GoogleDrive:Scanned
```

## Usage
```
usage:
  --destination       The destination to copy the files. (required)
  --unique-filenames  Makes all file names unique when uploading.
```
