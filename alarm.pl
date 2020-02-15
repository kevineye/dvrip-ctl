#!/usr/bin/perl
use Mojolicious::Lite -strict, -signatures, -async_await;

use lib 'lib';

use IPCam::Alarm::HomeAssistant;
use IPCam::Alarm::Log;
use IPCam::Alarm::Slack;
use IPcam;

plugin 'yaml_config' => { class => 'YAML' };
my $config = app->stash('config');
my $cameras = {};

async sub init_camera($id) {
  my $cam = $cameras->{$id} = IPcam->new(%{$config->{cameras}{$id}});
  await $cam->connect;
  await $cam->cmd_login;
  die "cannot connect to $id (${\$cam->host}:${\$cam->port})\n" unless $cam->sid;
  return $cam;
}

async sub startup {
  Mojo::Promise->all(map {init_camera($_)} keys %{$config->{cameras}})->wait;

  for my $conf (@{$config->{alarms}}) {
    my $type = delete $conf->{type};
    my @cameras = @{delete $conf->{cameras} || []};
    IPCam::Alarm->new_of_type($type, name => $_, camera => $cameras->{$_}, %$conf)->start for @cameras;
  }

  # my $on = 1;
  # my $as = $cameras->{cam_1}->alarm_stream;
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
