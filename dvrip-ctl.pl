#!/usr/bin/perl
use Mojo::Base -strict, -signatures, -async_await;

use lib 'lib';
use IPcam;

use Getopt::Long;
use Mojo::JSON qw(encode_json decode_json);

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
  ls                      <start> <end> (formats: YYYY-MM-DD HH:MM:SS or epoch or negative offset from now)
  download                { <file from ls> } <filename.h264|mkv|mp4|jpg> (any ffmpeg format)
  set_time                <nortc>
  export_config           <filename.tar.gz>
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

my @a = ();
push @a, host => $host if defined $host;
push @a, port => $port if defined $port;
push @a, user => $user if defined $user;
push @a, password => $pass if defined $pass;
push @a, debug => $debug if defined $debug;

async sub main {
  my $cam = IPcam->new(@a);
  await $cam->connect;

  $| = 1;

  my $res = await $cam->cmd_login;
  die "cannot connect\n" unless $cam->{sid};
  die "authentication failed\n" if $res->{Ret} >= 200;

  my $method = "cmd_$cmd";
  die "invalid command '$cmd'\n" unless $cam->can($method);
  my @params = map {/^[{\[]/ ? decode_json $_ : $_} @ARGV;

  $res = await $cam->$method(@params);

  if ($res != 1) {
    print encode_json($res);
  }
}

main()->catch(sub { warn @_; exit -1 })->wait;
