#!/usr/bin/perl
use Mojolicious::Lite -strict, -signatures, -async_await;

use lib 'lib';

use IPcam;
use IPCam::WarpVideo;

async sub startup {
  my $cam = IPcam->new(host => $ENV{DVRIP_HOST}, password => $ENV{DVRIP_PASS}, debug => 0);
  await $cam->connect;
  await $cam->cmd_login;
  die "cannot connect\n" unless $cam->{sid};
  my $warp = IPCam::WarpVideo->new(camera => $cam, dir => 'warp');
  $warp->start;
}

startup->catch(sub {
  warn @_;
  exit -1
})->wait;

app->start;
