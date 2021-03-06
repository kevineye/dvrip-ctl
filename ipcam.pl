#!/usr/bin/perl
use Mojolicious::Lite -strict, -signatures, -async_await;

use lib 'lib';

use IPCam;
use IPCam::Alarm::HomeAssistant;
use IPCam::Alarm::Log;
use IPCam::Alarm::Slack;
use IPCam::WarpVideo;

plugin 'yaml_config' => { class => 'YAML' };
my $config = app->stash('config');
my $cameras = {};

async sub init_camera($id) {
  my $cam = $cameras->{$id} = IPCam->new(log => app->log, %{$config->{cameras}{$id}});
  await $cam->connect;
  await $cam->cmd_login;
  die "cannot connect to $id (${\$cam->host}:${\$cam->port})\n" unless $cam->sid;
  return $cam;
}

async sub main {
  Mojo::Promise->all(map {init_camera($_)} keys %{$config->{cameras}})->wait;

  for my $conf (@{$config->{alarms}}) {
    my $type = delete $conf->{type};
    my @cameras = @{delete $conf->{cameras} || []};
    IPCam::Alarm->new_of_type($type, name => $_, app => app, camera => $cameras->{$_}, camera_name => $_, %$conf)->start for @cameras;
  }

  for my $conf (@{$config->{warp}}) {
    my @cameras = @{delete $conf->{cameras} || []};
    IPCam::WarpVideo->new(name => $_, app => app, camera => $cameras->{$_}, %$conf)->start for @cameras;
  }

  # simulate connection close
  # Mojo::IOLoop->timer(10 => sub {
  #   warn "shut it down!";
  #   $cameras->{cam_1}->stream->close;
  # });

  # simulate stream of motion events
  # my $on = 1;
  # my $as = $cameras->{cam_1}->alarm_stream;
  # Mojo::IOLoop->recurring(10 => sub {
  #   $as->emit(alarm => { Channel => 0, Event => "VideoMotion", StartTime => "2020-02-13 20:37:34", Status => ($on ? "Start" : "Stop") });
  #   $on = !$on;
  # });

  return 1;
}

main()->catch(sub {app->log->error($@)})->wait;
app->start;
