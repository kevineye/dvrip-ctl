Controller for dvr-ip/sofia protocol IP cameras.

## Example usage

Get camera capabilities:

    dvrip-ctl.pl -host 192.168.1.100 -pass changeme \
      system_info
    dvrip-ctl.pl -host 192.168.1.100 -pass changeme \
      system_function
    dvrip-ctl.pl -host 192.168.1.100 -pass changeme \
      storage_info

Grab 5 seconds of video:

    dvrip-ctl.pl -host 192.168.1.100 -pass changeme \
      monitor out.mp4 5

Grab a video snapshot (fast but low-resolution):

    dvrip-ctl.pl -host 192.168.1.100 -pass changeme \
      snap out.jpg

Grab a snapshot from the video stream (slower, but high-resolution):

    dvrip-ctl.pl -host 192.168.1.100 -pass changeme \
      monitor out.jpg

Monitor for "alarms" (events, like motion detected):

    dvrip-ctl.pl -host 192.168.1.100 -pass changeme \
      alarm_start

Move PTZ camera:

    # relative (move left for 500 ms)
    dvrip-ctl.pl -host 192.168.1.100 -pass changeme \
      ptz left 500

    # save preset
    dvrip-ctl.pl -host 192.168.1.100 -pass changeme \
      ptz_set_preset 0

    # absolute-ish (2000 ms from top, 18000ms from left)
    dvrip-ctl.pl -host 192.168.1.100 -pass changeme \
      ptz_abs 2000 18000

    # go back to preset
    dvrip-ctl.pl -host 192.168.1.100 -pass changeme \
      ptz_goto_preset 0

List and download files:

    # list videos from last hour
    dvrip-ctl.pl -host 192.168.1.100 -pass changeme \
      ls 3600 0

    # download file from list
    dvrip-ctl.pl -host 192.168.1.100 -pass changeme \
      download { insert json from ls } video.mp4

Get and set settings:

    dvrip-ctl.pl -host 192.168.1.100 -pass changeme \
      config_get General

    dvrip-ctl.pl -host 192.168.1.100 -pass changeme \
      config_get Detect.MotionDetect[0]

    dvrip-ctl.pl -host 192.168.1.100 -pass changeme \
      config_set Detect.MotionDetect[0].Enable true

Run in docker:

    docker build -t dvrip-ctl .
    
    docker run --rm -it \
      -e DVRIP_HOST=192.168.1.100 \
      -e DVRIP_PASS=changeme \
      dvrip-ctl \
        config_get General

---

Code adapted and extended from https://github.com/667bdrm/sofiactl
