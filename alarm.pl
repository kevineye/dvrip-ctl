#!/usr/bin/perl
use Mojolicious::Lite -strict, -signatures, -async_await;

use lib 'lib';

use IPCam::Alarm::HomeAssistant;
use IPCam::Alarm::Log;
use IPCam::Alarm::Slack;
use IPcam;

async sub startup {
  my $cam = IPcam->new(host => $ENV{DVRIP_HOST}, password => $ENV{DVRIP_PASS});
  await $cam->connect;
  await $cam->cmd_login;

  die "cannot connect\n" unless $cam->{sid};

  IPCam::Alarm::Log->new(camera => $cam, name => "coop")->start;

  IPCam::Alarm::HomeAssistant->new(
    camera         => $cam,
    name           => "Coop Motion",
    ha_sensor_name => 'cam_1_motion',
    ha_url         => 'https://home.kevin-eye.com',
    ha_token       => 'x',
  )->start;

  IPCam::Alarm::Slack->new(
    camera      => $cam,
    name           => "coop motion",
    slack_url   => 'https://hooks.slack.com/services/x',
  )->start;

  # my $on = 1;
  # my $as = $cam->alarm_stream;
  # Mojo::IOLoop->recurring(10 => sub {
  #   $as->emit(alarm => { Channel => 0, Event => "VideoMotion", StartTime => "2020-02-13 20:37:34", Status => ($on ? "Start" : "Stop") });
  #   $on = !$on;
  # });

  return 1;
}

startup->catch(sub {
  warn @_;
  exit -1
})->wait;

app->start;
