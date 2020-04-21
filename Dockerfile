FROM alpine:3.7

RUN apk --no-cache add bash inotify-tools ca-certificates && \
	apk --no-cache add --virtual=build-dependencies wget curl unzip && \
	wget -o rclone.zip https://downloads.rclone.org/v1.40/rclone-v1.40-linux-386.zip && \
	unzip rclone-v1.40-linux-386.zip && \
	cp rclone-v1.40-linux-386/rclone /usr/local/bin/rclone && \
	rm -rf rclone-v1.40-linux-386 && \
	rm rclone-v1.40-linux-386.zip && \
	apk del --purge build-dependencies && \
	mkdir -p /etc/supervisord

COPY bin/* /usr/local/bin/

VOLUME ["/config", "/files"]

ENTRYPOINT ["/usr/local/bin/monitor_files.sh"]
