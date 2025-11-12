# Used on the AP Pi to log the activity as the MP4 file is being streamed.
# Located in the tcp_demo folder

#!/usr/bin/env python3
import socket, sys
if len(sys.argv) < 2:
    print("Usage: client.py <CLIENT_IP> [START|STOP]"); raise SystemExit(1)
ip = sys.argv[1]
msg = (sys.argv[2] if len(sys.argv)>2 else "START") + "\n"
with socket.create_connection((ip,7000), timeout=5) as s:
    s.sendall(msg.encode()); print(s.recv(1024).decode(), end="")
