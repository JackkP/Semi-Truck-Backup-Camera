# Used to stop the stream

#!/usr/bin/env bash
CLIENT_IP="192.168.50.3"
python3 ~/tcp_demo/client.py "$CLIENT_IP" STOP
pkill -f "gst-launch-1.0.*tcpserversink.*port=5000" || true
