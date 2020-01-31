#!/usr/bin/perl
use strict;
use warnings;

use lib 'lib';
use IPcam;

use Getopt::Long;
use JSON;

GetOptions(
  "help|h"          => \my $help,
  "user=s"          => \my $user,
  "pass=s"          => \my $pass,
  "host=s"          => \my $host,
  "port=s"          => \my $port,
  "debug|d"         => \my $debug,
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
  set_time                <nortc>
  export_config           <filename.tar.gz>
  ptz                     <up|down|left|right> <ms>
  ptz_preset              <x_ms> <y_ms>
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

  alarm_info              { ... }
  net_keyboard            { ... }
  storage_manager         { "Action: "Clear/Recover/Partition/SetType", ... } - see OPStorageManager
  file_query              { ... } - see OPFileQuery
  log_query               { ... } - see OPLogQuery
  ptz_control             { ... } - see OPPTZControl

  alarm_center_message    (not working)
  net_alarm               (not working)

  work_state              (invalid)
  export_log              (invalid)
  oem_info                (invalid)
USAGE
}

my $cam = IPcam->new(
  host     => $host,
  port     => $port,
  user     => $user,
  password => $pass,
  debug    => $debug,
);

$| = 1;

my $res = $cam->cmd_login;
die "cannot connect\n" unless $cam->{sid};
die "authentication failed\n" if $res->{Ret} >= 200;

my $method = "cmd_$cmd";
die "invalid command '$cmd'\n" unless $cam->can($method);
my @params = map { /^[{\[]/ ? decode_json $_ : $_ } @ARGV;

$res = $cam->$method(@params);

if ($res != 1) {
  print encode_json($res);
}
