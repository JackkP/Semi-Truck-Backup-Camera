# Used to tell the AP Pi to start and then send the MP4 file.
# Located in the tcp_demo folder

#!/usr/bin/env bash
set -euo pipefail
CLIENT_IP="192.168.50.3"   # set your client IP
: "${FILE:=/home/user/tcp_demo/WAP_stream_test/test.mp4}"
[ -f "$FILE" ] || { echo "ERROR: File not found: $FILE"; exit 1; }

python3 ~/tcp_demo/client.py "$CLIENT_IP" START
sleep 1

# Stream Start command below
gst-launch-1.0 -v \
  filesrc location="$FILE" ! qtdemux name=dmx \
    dmx.video_0 ! queue ! h264parse config-interval=-1 ! \
      video/x-h264,stream-format=byte-stream,alignment=au ! \
  mpegtsmux ! tcpserversink host=0.0.0.0 port=5000
