#!/usr/bin/perl
use Mojo::Base -strict, -signatures, -async_await;

use FindBin '$RealBin';
use lib "$RealBin/lib";

use Getopt::Long;
use IPCam;
use Mojo::JSON qw(encode_json decode_json);

GetOptions(
  "help|h"  => \my $help,
  "user=s"  => \my $user,
  "pass=s"  => \my $pass,
  "host=s"  => \my $host,
  "port=s"  => \my $port,
  "debug|d" => \my $debug,
);

$host ||= $ENV{DVRIP_HOST};
$port ||= $ENV{DVRIP_PORT};
$user ||= $ENV{DVRIP_USER};
$pass ||= $ENV{DVRIP_PASS};

my $cmd = shift;

if ($help || !$host || !$pass || !$cmd) {
  die <<USAGE;
Usage: $0 <options> command

Options:
  -h | -help
  -host
  -port
  -user
  -pass
  -o | -outputfile
  -d | -debug

Commands:
  system_info
  storage_info
  system_function
  users
  groups
  alarm_start

  snap                    <filename.jpg>
  monitor                 <filename.h264|mkv|mp4|jpg> [seconds] (any ffmpeg format)
  ls                      <start> <end> (formats: YYYY-MM-DD HH:MM:SS or epoch or negative offset from now)
  download                { <file from ls> } <filename.h264|mkv|mp4|jpg> (any ffmpeg format)
  config_export           <filename.zip>
  ptz                     <up|down|left|right> <ms>
  ptz_set_preset          <num>
  ptz_goto_preset         <num>
  ptz_abs                 <x_ms> <y_ms>
  config_get              General
                          AppDowloadLink
                          AVEnc
                          Camera
                          ChannelTitle
                          Consumer
                          Detect
                          fVideo
                          NetWork
                          OPMachine
                          Simplify.Encode
                          Uart
  config_set              <config> <value | json>

USAGE
}

my @a = ();
push @a, host => $host if defined $host;
push @a, port => $port if defined $port;
push @a, user => $user if defined $user;
push @a, password => $pass if defined $pass;
push @a, debug => $debug if defined $debug;

async sub main {
  my $cam = IPCam->new(@a);
  await $cam->connect;

  $| = 1;

  my $res = await $cam->cmd_login;
  die "cannot connect\n" unless $cam->{sid};
  die "authentication failed\n" if $res->{Ret} >= 200;

  my $method = "cmd_$cmd";
  die "invalid command '$cmd'\n" unless $cam->can($method);
  my @params = map {/^[{\[]/ ? decode_json $_ : $_} @ARGV;

  if ($cmd eq 'alarm_start') {
    my $stream = $cam->$method;
    $stream->on(alarm => sub($, $a) {print encode_json($a) . "\n"});
    my $p = Mojo::Promise->new;
    return $p;
  }
  else {
    $res = await $cam->$method(@params);
    if ($res != 1) {
      print encode_json($res);
    }
  }
}

main()->catch(sub {
  warn @_;
  exit -1
})->wait;
