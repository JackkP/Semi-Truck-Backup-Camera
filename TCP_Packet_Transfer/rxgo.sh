# rxgo file used to start the listening process on the client Pi which will display the mp4 file.
# Without rxgo, we run into an error saying no file received or found, this way we keep listening.
# Autoselects the sink, kmssink for console and autovideosink for desktop.
# run this file on the client with 'rxgo'

#!/usr/bin/env bash
set -euo pipefail
AP_IP="${1:-${AP_IP:-192.168.50.1}}"
PORT="${2:-${PORT:-5000}}"
SINK=${SINK_OVERRIDE:-$([ -n "${DISPLAY:-}" ] && echo autovideosink || echo kmssink)}
until (echo > /dev/tcp/$AP_IP/$PORT) 2>/dev/null; do sleep 0.3; done
exec gst-launch-1.0 \
  tcpclientsrc host="$AP_IP" port="$PORT" ! \
  tsdemux ! h264parse ! avdec_h264 ! videoconvert ! \
  fpsdisplaysink text-overlay=true video-sink=$SINK sync=false
