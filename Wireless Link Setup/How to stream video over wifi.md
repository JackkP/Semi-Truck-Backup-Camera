How to stream video over wifi:

# 1. install gstreamer and plugins on raspberry pi and video device
sudo apt update
sudo apt install gstreamer1.0-tools \
                 gstreamer1.0-plugins-base \
                 gstreamer1.0-plugins-good \
                 gstreamer1.0-plugins-bad \
                 gstreamer1.0-plugins-ugly \
                 gstreamer1.0-libav


# 2. start streaming video on client:
# note that it's important that the video is encoded with bt709 SD not HD.
gst-launch-1.0 filesrc location=output_fixed.mp4 ! decodebin ! x264enc tune=zerolatency bitrate=2000 speed-preset=ultrafast ! rtph264pay ! udpsink host=192.168.4.35 port=5000

# windows loop
for ($i = 0; $i -lt 10; $i++) {
    gst-launch-1.0 filesrc location="C:/Users/jacki/Downloads/WAP_stream_test/output_fixed.mp4" ! decodebin ! x264enc tune=zerolatency bitrate=2000 speed-preset=ultrafast key-int-max=30 ! video/x-h264,profile=baseline ! rtph264pay config-interval=1 pt=96 ! udpsink host=192.168.50.1 port=5000
}

# 3. start receiving video on host:
gst-launch-1.0 udpsrc port=5000 caps="application/x-rtp,media=video,encoding-name=H264,payload=96" ! rtph264depay ! h264parse ! v4l2h264dec ! fbdevsink

# alternatively start with FPS overlay
gst-launch-1.0 udpsrc port=5000 caps="application/x-rtp,media=video,encoding-name=H264,payload=96" ! rtph264depay ! h264parse ! v4l2h264dec ! fpsdisplaysink video-sink=fbdevsink

# save to a file instead
gst-launch-1.0 udpsrc port=5000 caps="application/x-rtp,media=video,encoding-name=H264,payload=96" ! rtph264depay ! h264parse ! mp4mux ! filesink location=output.mp4


# 4. optional
# watch incoming UDP stream datarate:
sudo nload wlan0 # replace wlan0 with the adapter name
# check bitrate of mp4 file (if streaming mp4 video)
ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1 MotionTest.mp4

