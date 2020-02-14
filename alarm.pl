#!/usr/bin/perl
use Mojolicious::Lite -strict, -signatures, -async_await;

use lib 'lib';

use IPcam;
use IPCam::Alarm::Log;

async sub startup {
  my $cam = IPcam->new(host => $ENV{DVRIP_HOST}, password => $ENV{DVRIP_PASS});
  await $cam->connect;
  await $cam->cmd_login;
  die "cannot connect\n" unless $cam->{sid};
  my $alarm = IPCam::Alarm::Log->new(camera => $cam);
  $alarm->start;
}

startup->catch(sub {
  warn @_;
  exit -1
})->wait;

app->start;
