# Used on the Client Pi, and it lives in the tcp_demo folder on the Pi.
# Listens to the AP Pi and waits for a command, START or STOP

#!/usr/bin/env python3
import socket, subprocess
HOST, PORT = "0.0.0.0", 7000
def act(cmd):
    cmd = cmd.strip().upper()
    AP_IP = "192.168.50.1"  # set to your AP IP
    if cmd == "START":
        pipe = (
          f"gst-launch-1.0 -v tcpclientsrc host={AP_IP} port=5000 ! "
          "tsdemux ! h264parse ! avdec_h264 ! videoconvert ! autovideosink sync=false"
        )
        subprocess.Popen(["bash","-lc", pipe],
                         stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
        return b"OK START\n"
    if cmd == "STOP":
        subprocess.Popen(["bash","-lc","pkill -f 'gst-launch-1.0.*tcpclientsrc' || true"])
        return b"OK STOP\n"
    return b"ERR UNKNOWN\n"
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind((HOST, PORT)); s.listen(5)
    print(f"Listening on {HOST}:{PORT}")
    while True:
        c, a = s.accept()
        with c:
            data = c.recv(1024).decode(errors="ignore")
            c.sendall(act(data))
