package IPCam;
use Mojo::Base 'Mojo::EventEmitter', -strict, -signatures, -async_await;

# initially from https://github.com/667bdrm/sofiactl

use Digest::MD5 qw(md5 md5_hex);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::Log;
use Mojo::Promise;
use Time::Local;
use Time::HiRes qw(usleep);

has stream => undef;
has alarm_stream => undef;
has host => undef;
has port => 34567;
has user => 'admin';
has password => undef;
has sid => 0;
has sequence => 0;
has hashtype => 'md5based';
has log => sub {Mojo::Log->new};
has reconnect_delay => 30;

our $message_id = {
  login_req                      => 1000, # 999
  login_rsp                      => 1001,
  logout_req                     => 1002,
  logout_rsp                     => 1003,
  forcelogout_req                => 1004,
  forcelogout_rsp                => 1005,
  keepalive_req                  => 1006, # 1005
  keepalive_rsp                  => 1007, # 1006

  sysinfo_req                    => 1020,
  sysinfo_rsp                    => 1021,

  config_set                     => 1040,
  config_set_rsp                 => 1041,
  config_get                     => 1042,
  config_get_rsp                 => 1043,
  default_config_get             => 1044,
  default_config_get_rsp         => 1045,
  config_channeltile_set         => 1046,
  config_channeltile_set_rsp     => 1047,
  config_channeltile_get         => 1048,
  config_channeltile_get_rsp     => 1049,
  config_channeltile_dot_set     => 1050,
  config_channeltile_dot_set_rsp => 1051,

  system_debug_req               => 1052,
  system_debug_rsp               => 1053,

  ability_req                    => 1360,
  ability_rsp                    => 1361,

  ptz_req                        => 1400,
  ptz_rsp                        => 1401,

  monitor_req                    => 1410,
  monitor_rsp                    => 1411,
  monitor_data                   => 1412,
  monitor_claim                  => 1413,
  monitor_claim_rsp              => 1414,

  play_req                       => 1420,
  play_rsp                       => 1421,
  play_data                      => 1422,
  play_eof                       => 1423,
  play_claim                     => 1424,
  play_claim_rsp                 => 1425,
  download_data                  => 1426,

  talk_req                       => 1430,
  talk_rsp                       => 1431,
  talk_cu_pu_data                => 1432,
  talk_pu_cu_data                => 1433,
  talk_claim                     => 1434,
  talk_claim_rsp                 => 1435,

  filesearch_req                 => 1440,
  filesearch_rsp                 => 1441,
  logsearch_req                  => 1442,
  logsearch_rsp                  => 1443,
  filesearch_bytime_req          => 1444,
  filesearch_bytime_rsp          => 1445,

  sysmanager_req                 => 1450,
  sysmanager_rsp                 => 1451,
  timequery_req                  => 1452,
  timequery_rsp                  => 1453,

  diskmanager_req                => 1460,
  diskmanager_rsp                => 1461,

  fullauthoritylist_get          => 1470,
  fullauthoritylist_get_rsp      => 1471,
  users_get                      => 1472,
  users_get_rsp                  => 1473,
  groups_get                     => 1474,
  groups_get_rsp                 => 1475,
  addgroup_req                   => 1476,
  addgroup_rsp                   => 1477,
  modifygroup_req                => 1478,
  modifygroup_rsp                => 1479,
  deletegroup_req                => 1480,
  deletegroup_rsp                => 1481,
  adduser_req                    => 1482,
  adduser_rsp                    => 1483,
  modifyuser_req                 => 1484,
  modifyuser_rsp                 => 1485,
  deleteuser_req                 => 1486,
  deleteuser_rsp                 => 1487,
  modifypassword_req             => 1488,
  modifypassword_rsp             => 1489,

  guard_req                      => 1500,
  guard_rsp                      => 1501,
  unguard_req                    => 1502,
  unguard_rsp                    => 1503,
  alarm_req                      => 1504,
  alarm_rsp                      => 1505,
  net_alarm_req                  => 1506,
  net_alarm_rsp                  => 1507,
  alarmcenter_msg_req            => 1508,

  upgrade_req                    => 1520,
  upgrade_rsp                    => 1521,
  upgrade_data                   => 1522,
  upgrade_data_rsp               => 1523,
  upgrade_progress               => 1524,
  upgrade_info_req               => 1525,
  upgrade_info_rsq               => 1526,

  ipsearch_req                   => 1530,
  ipsearch_rsp                   => 1531,
  ip_set_req                     => 1532,
  ip_set_rsp                     => 1533,

  config_import_req              => 1540,
  config_import_rsp              => 1541,
  config_export_req              => 1542,
  config_export_rsp_data         => 1543,
  log_export_req                 => 1544, #condig_export_req
  log_export_rsp_data            => 1545, #config_export_rsp

  net_keyboard_req               => 1550,
  net_keyboard_rsp               => 1551,

  net_snap_req                   => 1560,
  net_snap_rsp_data              => 1561,
  set_iframe_req                 => 1562,
  set_iframe_rsp                 => 1563,

  rs232_read_req                 => 1570,
  rs232_read_rsp                 => 1571,
  rs232_write_req                => 1572,
  rs232_write_rsp                => 1573,
  rs485_read_req                 => 1574,
  rs485_read_rsp                 => 1575,
  rs485_write_req                => 1576,
  rs485_write_rsp                => 1577,
  transparent_comm_req           => 1578,
  transparent_comm_rsp           => 1579,
  rs485_transparent_data_req     => 1580,
  rs485_transparent_data_rsp     => 1581,
  rs232_transparent_data_req     => 1582,
  rs232_transparent_data_rsp     => 1583,

  sync_time_req                  => 1590,
  sync_time_rsp                  => 1591,

  photo_get_req                  => 1600,
  photo_get_rsp                  => 1601,
};

our $message_id_reverse = { reverse % $message_id };

our $error_codes = {
  100 => "OK",
  101 => "unknown mistake",
  102 => "Version not supported",
  103 => "Illegal request",
  104 => "The user has logged in",
  105 => "The user is not logged in",
  106 => "username or password is wrong",
  107 => "No permission",
  108 => "time out",
  109 => "Failed to find, no corresponding file found",
  110 => "Find successful, return all files",
  111 => "Find success, return some files",
  112 => "This user already exists",
  113 => "this user does not exist",
  114 => "This user group already exists",
  115 => "This user group does not exist",
  116 => "Error 116",
  117 => "Wrong message format",
  118 => "PTZ protocol not set",
  119 => "No query to file",
  120 => "Configure to enable",
  121 => "MEDIA_CHN_NOT CONNECT digital channel is not connected",
  150 => "Successful, the device needs to be restarted",
  202 => "User not logged in",
  203 => "The password is incorrect",
  204 => "User illegal",
  205 => "User is locked",
  206 => "User is on the blacklist",
  207 => "Username is already logged in",
  208 => "Input is illegal",
  209 => "The index is repeated if the user to be added already exists, etc.",
  210 => "No object exists, used when querying",
  211 => "Object does not exist",
  212 => "Account is in use",
  213 =>
    "The subset is out of scope (such as the group's permissions exceed the permission table, the user permissions exceed the group's permission range, etc.)",
  214 => "The password is illegal",
  215 => "Passwords do not match",
  216 => "Retain account",
  502 => "The command is illegal",
  503 => "Intercom has been turned on",
  504 => "Intercom is not turned on",
  511 => "Already started upgrading",
  512 => "Not starting upgrade",
  513 => "Upgrade data error",
  514 => "upgrade unsuccessful",
  515 => "update successed",
  521 => "Restore default failed",
  522 => "Need to restart the device",
  523 => "Illegal default configuration",
  602 => "Need to restart the app",
  603 => "Need to restart the system",
  604 => "Error writing a file",
  605 => "Feature not supported",
  606 => "verification failed",
  607 => "Configuration does not exist",
  608 => "Configuration parsing error",
};

sub clone($self) {
  $self->new(
    host     => $self->host,
    port     => $self->port,
    user     => $self->user,
    password => $self->password,
    log      => $self->log,
  );
}

sub disconnect($self) {
  if ($self->stream) {
    $self->stream->unsubscribe('close');
    $self->stream->close;
  }
}

async sub connect {
  my ($self, $reconnect) = @_;
  $self->{buffer} = '';
  $self->{recv_header} = undef;

  my $p = Mojo::Promise->new;
  Mojo::IOLoop->client(address => $self->host, port => $self->port, sub($, $err, $stream) {
    if ($err) {
      $self->log->error("cannot connect to ${\$self->host}:${\$self->port}");
      $self->wait_reconnect;
      $p->reject("Cannot connect to camera at ${\$self->host}:${\$self->port}: $err\n");
    }
    else {
      $self->log->info("connected to ${\$self->host}:${\$self->port}");
      $self->stream($stream);
      $stream->timeout(0);
      $stream->on(error => sub {$self->stream_error($_[1])});
      $stream->on(read => sub {$self->stream_read($_[1])});
      $stream->on(close => sub {$self->stream_close});
      if ($reconnect) {
        return $self->cmd_login->then(sub {
          $self->_cmd_alarm_start if $self->alarm_stream;
          $p->resolve($self)
        });
      } else {
        $self->enable_keepalive;
        $p->resolve($self);
      }
    }
  });
  return $p;
}

sub enable_keepalive($self, $timeout = 20) {
  Mojo::IOLoop->recurring($timeout => sub {$self->cmd_keepalive});
}

sub stream_read($self, $bytes) {
  $self->{buffer} .= $bytes;
  while (1) {
    if ($self->{recv_header} && length $self->{buffer} >= $self->{recv_header}->{Content_Length}) {
      my $header = $self->{recv_header};
      my $data = substr $self->{buffer}, 0, $header->{Content_Length};
      $self->{recv_header} = undef;
      substr($self->{buffer}, 0, $header->{Content_Length}) = '';

      if ($header->{MessageId} && $header->{MessageId} !~ /_data$/) {
        $data =~ s/([\x00-\x20]*)\Z//ms; # trim off garbage at line ending
        $data = decode_json($data);
        $data->{'RetMessage'} = $error_codes->{$data->{'Ret'}} if $data->{'Ret'} && $error_codes->{$data->{'Ret'}};
      }
      $self->log->debug("<== received $header->{MessageId} packet with $header->{Content_Length} bytes of data");
      my $event_name = $header->{MessageId} || 'packet';
      $self->emit($event_name => ($data, $header));
    }
    elsif (!$self->{recv_header} && length $self->{buffer} >= 20) {
      $self->{recv_header} = $self->decode_head(substr $self->{buffer}, 0, 20);
      substr($self->{buffer}, 0, 20) = '';
      $self->log->debug("<== received complete header: " . encode_json($self->{recv_header}));
    }
    else {
      if (length $self->{buffer} > 0) {
        $self->log->debug("<-- buffered ${\length $self->{buffer}} bytes, but waiting for more...");
      }
      last;
    }
  }
}

sub wait_reconnect($self) {
  if ($self->reconnect_delay > 0) {
    Mojo::IOLoop->timer($self->reconnect_delay => sub {
      unless ($self->sid) {
        $self->log->info("reconnecting to ${\$self->host}:${\$self->port}");
        $self->connect(1);
      }
    });
  }
}

sub stream_close($self) {
  $self->log->warn("connection closed");
  $self->sid(undef);
  $self->wait_reconnect;
}

sub stream_error($self, $err) {
  $self->log->fatal("connection error: $err");
  $self->sid(undef);
  $self->wait_reconnect;
}

sub _build_packet_sid($self) {
  return sprintf("0x%08x", $self->sid);
}

sub build_packet($self, $type, $params) {
  my @pkt_prefix_1;
  my $pkt_type;

  @pkt_prefix_1 = (0xff, 0x00, 0x00, 0x00); # (head_flag, version (was 0x01), reserved01, reserved02)
  my $pkt_prefix_2 = 0x00;                  # (total_packets, cur_packet)

  $pkt_type = $type;

  if ($pkt_type eq 'fullauthoritylist_get') {
    $pkt_prefix_2 = 0x16;
  }
  elsif ($pkt_type eq 'deleteuser_req') {
    $pkt_prefix_2 = 0x06;
  }
  elsif ($pkt_type eq 'logsearch_req') {
    $pkt_prefix_2 = 0x22;
  }
  elsif ($pkt_type eq 'config_channeltile_set') {
    $pkt_prefix_2 = 0xa2;
  }
  elsif ($pkt_type eq 'config_set') {
    $pkt_prefix_2 = 0xae;
  }

  my $msgid = pack('s', 0) . pack('s', $message_id->{$pkt_type});

  my $pkt_prefix_data =
    pack('C*', @pkt_prefix_1)
      . pack('i', $self->sid)
      . pack('i', $self->sequence)
      . $msgid;

  my $pkt_params_data = '';

  if (defined $params) {
    $pkt_params_data = encode_json $params;
  }

  $pkt_params_data .= pack('C', 0x0a);

  my $pkt_data =
    $pkt_prefix_data
      . pack('i', length($pkt_params_data))
      . $pkt_params_data;

  $params->{Name} ||= '';
  $self->sequence($self->sequence + 1);

  return $pkt_data;
}

sub decode_head($self, $data) {
  my @head = unpack('CCCCiiCCSI', $data);
  my $head = {
    Version        => $head[1],
    SessionID      => $head[4],
    Sequence       => $head[5],
    Message_Code   => $head[8],
    Content_Length => $head[9],
    Channel        => $head[6],
    EndFlag        => $head[7],
  };
  $head->{'MessageId'} = $message_id_reverse->{$head[8]} if $head[8] && $message_id_reverse->{$head[8]};
  $self->sid($head[4]);
  return $head;
}

sub send_head($self, $msgid, $parameters) {
  my $cmd_data = $self->build_packet($msgid, $parameters);
  $self->stream->write($cmd_data);
  $self->log->debug("==> sending ${\length $cmd_data} byte $msgid request");
}

async sub send_command($self, $msgid, $resid, $parameters) {
  my $p = Mojo::Promise->new;
  $self->once($resid => sub($, $data, $head) {$p->resolve($data);});
  $self->send_head($msgid, $parameters);
  return $p;
}

async sub send_download_command($self, $msgid, $resid, $parameters, $file) {
  my $p = Mojo::Promise->new;
  $self->once($resid => sub($, $data, $head) {
    $self->log->debug(">>> writng > $file");
    open my $fh, '>', $file;
    print $fh $data;
    close $fh;
    $p->resolve(1);
  });
  $self->send_head($msgid, $parameters);
  return $p;
}

sub send_stream_command {
  my ($self, $msgid, $dataid, $parameters, $file, $mode) = @_;
  $mode ||= '>';
  my $p = Mojo::Promise->new;
  $self->log->debug(">>> writing $mode $file");
  open my ($fh), $mode, $file;
  my $cancelToken = Mojo::Promise->new;
  $cancelToken->finally(sub {
    $self->unsubscribe($dataid);
    close $fh;
    $p->resolve(1);
  });
  $self->on($dataid => sub($, $data, $head) {
    print $fh $data;
    $cancelToken->resolve if $head->{EndFlag};
  });
  $self->send_head($msgid, $parameters);
  return wantarray ? ($p, $cancelToken) : $p;
}

sub _md5_hash($self, $message) {
  my $hash = '';
  my $msg_md5 = md5($message);
  my @hash = unpack('C*', $msg_md5);
  for (my $i = 0; $i < 8; $i++) {
    my $n = ($hash[ 2 * $i ] + $hash[ 2 * $i + 1 ]) % 0x3e;
    if ($n > 9) {
      if ($n > 35) {
        $n += 61;
      }
      else {
        $n += 55;
      }
    }
    else {
      $n += 0x30;
    }
    $hash .= chr($n);
  }
  return $hash;
}

sub _plain_hash($, $message) {
  return $message;
}

sub _make_hash($self, $message) {
  if ($self->hashtype eq 'md5based') {
    return $self->_md5_hash($message);
  }
  else {
    return $self->_plain_hash($message);
  }
}

async sub cmd_login($self) {
  my $pkt = {
    EncryptType => "MD5",
    LoginType   => "DVRIP-Web",
    PassWord    => $self->_make_hash($self->password),
    UserName    => $self->user
  };
  $self->send_command('login_req', 'login_rsp', $pkt);
}

async sub cmd_system_info($self) {
  my $pkt = { Name => 'SystemInfo', };
  my $systeminfo = $self->send_command('sysinfo_req', 'sysinfo_rsp', $pkt);
  return $systeminfo;
}

async sub cmd_alarm_info($self, $parameters) {
  my $pkt = {
    Name      => 'AlarmInfo',
    AlarmInfo => $parameters,
  };
  return $self->send_command('alarm_req', 'alarm_rsp', $pkt);
}

async sub cmd_net_alarm($self) {
  my $pkt = {
    Name         => 'OPNetAlarm',
    NetAlarmInfo => {
      Event => 0,
      State => 1,
    },
  };
  return $self->send_command('net_alarm_req', 'net_alarm_rsp', $pkt);
}

async sub cmd_net_keyboard($self, $parameters) {
  my $pkt = {
    Name          => 'OPNetKeyboard',
    OPNetKeyboard => $parameters,
  };
  return $self->send_command('net_keyboard_req', 'net_keyboard_rsp', $pkt);
}

async sub cmd_users($self) {
  return $self->send_command('users_get', 'users_get_rsp', {});
}

async sub cmd_groups($self) {
  return $self->send_command('groups_get', 'groups_get_rsp', {});
}

async sub cmd_storage_info($self) {
  my $pkt = { Name => 'StorageInfo' };
  return $self->send_command('sysinfo_req', 'sysinfo_rsp', $pkt);
}

async sub cmd_work_state($self) {
  my $pkt = { Name => 'WorkState', };
  return $self->send_command('sysinfo_req', 'sysinfo_rsp', $pkt);
}

async sub cmd_snap($self, $out) {
  my $pkt = { Name => 'OPSNAP' };
  return $self->send_download_command('net_snap_req', 'net_snap_rsp_data', $pkt, $out);
}

async sub cmd_empty($self) {
  my $pkt = { Name => '' };
  return $self->send_command('sysinfo_req', 'sysinfo_rsp', $pkt);
}

async sub cmd_keepalive($self) {
  my $pkt = { Name => 'KeepAlive' };
  return $self->send_command('keepalive_req', 'keepalive_rsp', $pkt);
}

async sub cmd_monitor_claim($self) {
  my $pkt = {
    Name      => 'OPMonitor',
    OPMonitor => {
      Action    => "Claim",
      Parameter => {
        Channel    => 0,
        CombinMode => "CONNECT_ALL",
        StreamType => "Main",
        TransMode  => "TCP"
      }
    }
  };
  return $self->send_command('monitor_claim', 'monitor_claim_rsp', $pkt);
}

async sub cmd_monitor_stop($self) {
  my $pkt = {
    Name      => 'OPMonitor',
    SessionID => $self->_build_packet_sid(),
    OPMonitor => {
      Action    => "Stop",
      Parameter => {
        Channel    => 0,
        CombinMode => "NONE",
        StreamType => "Main",
        TransMode  => "TCP"
      }
    }
  };
  return $self->send_command('monitor_claim', 'monitor_claim_rsp', $pkt);
}

sub cmd_monitor_start($self, $file, $mode) {
  my $pkt = {
    Name      => 'OPMonitor',
    SessionID => $self->_build_packet_sid(),
    OPMonitor => {
      Action    => "Start",
      Parameter => {
        Channel    => 0,
        CombinMode => "NONE",
        StreamType => "Main",
        TransMode  => "TCP"
      }
    }
  };
  return $self->send_stream_command('monitor_req', 'monitor_data', $pkt, $file, $mode);
}

# TODO not updated for mojo/async
# sub cmd_set_time($self, $nortc) {
#   my ($sec, $min, $hour, $mday, $mon, $year) = localtime();
#
#   my $clock_cmd = 'OPTimeSetting';
#
#   my $pkt_type = SYSMANAGER_REQ;
#
#   if ($nortc) {
#     $clock_cmd .= 'NoRTC';
#     $pkt_type = SYNC_TIME_REQ;
#   }
#
#   my $pkt = {
#     Name         => $clock_cmd,
#     SessionID    => $self->_build_packet_sid(),
#     "$clock_cmd" => sprintf(
#       "%4d-%02d-%02d %02d:%02d:%02d",
#       $year + 1900,
#       $mon + 1, $mday, $hour, $min, $sec
#     )
#   };
#
#   my $cmd_data = $self->build_packet($pkt_type, $pkt);
#
#   $self->{socket}->send($cmd_data);
#   my $reply = $self->recv_head();
#   my $out = $self->recv_data($reply);
#
#   if ($out) {
#     # trim off garbage at line ending
#     $out =~ s/([\x00-\x20]*)\Z//ms;
#     return decode_json($out);
#   }
#
#   return undef;
# }

async sub cmd_system_function($self) {
  my $pkt = { Name => 'SystemFunction' };
  return $self->send_command('ability_req', 'ability_rsp', $pkt);
}

async sub cmd_file_query($self, $parameters) {
  my $pkt = {
    Name        => 'OPFileQuery',
    OPFileQuery => $parameters,
  };
  return $self->send_command('filesearch_req', 'filesearch_rsp', $pkt);
}

async sub cmd_oem_info($self) {
  my $pkt = { Name => 'OEMInfo' };
  return $self->send_command('sysinfo_req', 'sysinfo_rsp', $pkt);
}

async sub cmd_playback($self, $parameters) {
  my $pkt = {
    Name       => 'OPPlayBack',
    OPPlayBack => $parameters,
  };
  return $self->send_command('play_claim', 'play_claim_rsp', $pkt);
}

sub cmd_playback_download_start($self, $parameters, $file, $mode) {
  my $pkt = {
    Name       => 'OPPlayBack',
    OPPlayBack => $parameters,
  };
  return $self->send_stream_command('play_req', 'download_data', $pkt, $file, $mode);
}

async sub cmd_log_query($self, $parameters) {
  my $pkt = {
    Name       => 'OPLogQuery',
    OPLogQuery => $parameters,
  };
  return $self->send_command('logsearch_req', 'logsearch_rsp', $pkt);
}

# TODO not working
# async sub cmd_export_log {
#   my ($self, $file) = @_;
#   $file ||= 'logs.zip';
#   my $pkt = { Name => '' };
#   return $self->send_download_command(LOG_EXPORT_REQ, $pkt, $file);
# }

async sub cmd_config_export {
  my ($self, $file) = @_;
  $file ||= 'conf.zip';
  my $pkt = { Name => '' };
  return $self->send_download_command('config_export_req', 'config_export_rsp_data', $pkt, $file);
}

async sub cmd_storage_manager($self, $parameters) {
  my $pkt = {
    Name             => 'OPStorageManager',
    OPStorageManager => $parameters,
    SessionID        => $self->_build_packet_sid(),
  };
  return $self->send_command('diskmanager_req', 'diskmanager_rsp', $pkt);
}

async sub cmd_config_get($self, $parameters) {
  my $pkt = { Name => $parameters };
  return $self->send_command('config_get', 'config_get_rsp', $pkt);
}

async sub cmd_config_set($self, $name, $value) {
  my $pkt = { Name => $name, $name => $value };
  return $self->send_command('config_set', 'config_set_rsp', $pkt);
}

async sub cmd_ptz_control($self, $parameters) {
  my $pkt = { Name => 'OPPTZControl', OPPTZControl => $parameters };
  return $self->send_command('ptz_req', 'ptz_rsp', $pkt);
}

async sub cmd_ptz {
  my ($self, $direction, $ms) = @_;
  $direction ||= 'left';
  $ms ||= 500;
  $direction = "Direction" . ucfirst(lc($direction)) unless $direction =~ /^[A-Z]/;
  my $remainder = 0;
  if ($ms > 9000) {
    $remainder = $ms - 9000;
    $ms = 9000;
  }
  my $res = await $self->cmd_ptz_control({
    "Command"   => $direction,
    "Parameter" => {
      "AUX"      => {
        "Number" => 0,
        "Status" => "On"
      },
      "Channel"  => 0,
      "MenuOpts" => "Enter",
      "POINT"    => {
        "bottom" => 0,
        "left"   => 0,
        "right"  => 0,
        "top"    => 0
      },
      "Pattern"  => "SetBegin",
      "Preset"   => 65535,
      "Step"     => 8,
      "Tour"     => 0,
    }
  });
  return $res unless $res->{Ret} == 100;
  my $p = Mojo::Promise->new;
  Mojo::IOLoop->timer($ms / 1000, sub {
    $self->cmd_ptz_control({
      "Command"   => $direction,
      "Parameter" => {
        "AUX"      => {
          "Number" => 0,
          "Status" => "On"
        },
        "Channel"  => 0,
        "MenuOpts" => "Enter",
        "POINT"    => {
          "bottom" => 0,
          "left"   => 0,
          "right"  => 0,
          "top"    => 0
        },
        "Pattern"  => "SetBegin",
        "Preset"   => -1,
        "Step"     => 8,
        "Tour"     => 0,
      }
    })->then(sub {
      if ($remainder > 0 && $_[0]->{Ret} == 100) {
        $self->cmd_ptz($direction, $remainder)->then(sub {$p->resolve($_[0])});
      }
      else {
        $p->resolve($res);
      }
    });
  });
  return $p;
}

async sub cmd_ptz_set_preset($self, $preset) {
  return $self->cmd_ptz_control({
    "Command"   => "SetPreset",
    "Parameter" => {
      "AUX"      => {
        "Number" => 0,
        "Status" => "On"
      },
      "Channel"  => 0,
      "MenuOpts" => "Enter",
      "POINT"    => {
        "bottom" => 0,
        "left"   => 0,
        "right"  => 0,
        "top"    => 0
      },
      "Pattern"  => "Start",
      "Preset"   => $preset + 0,
      "Step"     => 10,
      "Tour"     => 0,
    }
  });
}

async sub cmd_ptz_goto_preset($self, $preset) {
  return $self->cmd_ptz_control({
    "Command"   => "GotoPreset",
    "Parameter" => {
      "AUX"      => {
        "Number" => 0,
        "Status" => "On"
      },
      "Channel"  => 0,
      "MenuOpts" => "Enter",
      "POINT"    => {
        "bottom" => 0,
        "left"   => 0,
        "right"  => 0,
        "top"    => 0
      },
      "Pattern"  => "Start",
      "Preset"   => $preset + 0,
      "Step"     => 10,
      "Tour"     => 0,
    }
  });
}

async sub cmd_ptz_abs($self, $x, $y) {
  await $self->cmd_ptz(up => 5000);
  await $self->cmd_ptz(left => 27000);
  await $self->cmd_ptz(right => $x);
  await $self->cmd_ptz(down => $y);
}

sub cmd_alarm_start($self) {
  unless ($self->alarm_stream) {
    my $stream = Mojo::EventEmitter->new;
    $self->alarm_stream($stream);
    $self->on(alarm_req => sub($, $data, $head) {$stream->emit(alarm => $data->{AlarmInfo})});
    $self->_cmd_alarm_start;
  }
  return $self->alarm_stream;
}

sub _cmd_alarm_start($self) {
  my $pkt = {
    Name      => '',
    SessionID => $self->_build_packet_sid(),
  };
  $self->send_command('guard_req', 'guard_rsp', $pkt);
}

sub _get_transcode_args($, $file, $seconds = 0) {
  $file ||= 'out.h264';
  my $mode = '>';
  return (substr($file, 1), '|-') if $file =~ /^\|/;
  unless ($file =~ /\.h264$/) {
    $mode = '|-';
    if ($file =~ /\.jpe?g|\.png/) {
      $file = "ffmpeg -loglevel panic -hide_banner -f h264 -i - -frames:v 1 -y '$file'";
    }
    else {
      my $time = $seconds ? "-t $seconds " : "";
      $file = "ffmpeg -loglevel panic -hide_banner -f h264 -i - -c copy -y $time '$file'";
    }
  }
  return($file, $mode);
}

async sub cmd_monitor {
  my ($self, $file, $seconds) = @_;
  my $c2 = $self->clone;
  await $c2->connect;
  my $res = await $c2->cmd_login;
  return $res unless $res->{Ret} == 100;
  $res = await $c2->cmd_monitor_claim;
  return $res unless $res->{Ret} == 100;
  my ($f, $m) = $c2->_get_transcode_args($file, $seconds);
  if ($seconds) {
    my $cancel;
    my $p = Mojo::Promise->new;
    Mojo::IOLoop->timer($seconds + 0.5 => sub {
      $cancel->resolve;
      $c2->disconnect;
      $p->resolve(1);
    });
    (undef, $cancel) = $c2->cmd_monitor_start($f, $m);
    return $p;
  }
  else {
    return $c2->cmd_monitor_start($f, $m);
  }
}

sub _parse_relative_time($self, $ts) {
  if ($ts =~ /^\d*$/) {
    $ts = time - $ts if $ts < 100000000;
    my @t = localtime $ts;
    return sprintf '%04d-%02d-%02d %02d:%02d:%02d', $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0];
  }
  else {
    return $ts;
  }
}

async sub cmd_ls {
  my ($self, $begin, $end) = @_;
  $begin = $self->_parse_relative_time($begin // 3600);
  $end = $self->_parse_relative_time($end // 0);
  my $res = await $self->cmd_file_query({
    BeginTime      => $begin,
    EndTime        => $end,
    Channel        => 0,
    # search all channels instead of single
    #HighChannel => 0,
    #LowChannel => 255,
    DriverTypeMask => "0x0000FFFF",
    Event          => "*",    # * - All; A - Alarm; M - Motion Detect; R - General; H - Manual;
    Type           => "h264", #h264 or jpg
  });
  return $res->{OPFileQuery} || [];
}

async sub cmd_download {
  my ($self, $file_rec, $outname) = @_;
  $outname ||= 'out.h264';
  my $res = await $self->cmd_playback({
    Action    => "Claim",
    StartTime => $file_rec->{'BeginTime'},
    EndTime   => $file_rec->{'EndTime'},
    Parameter => {
      FileName  => $file_rec->{'FileName'},
      PlayMode  => "ByName",
      TransMode => "TCP",
      Value     => 0
    }
  });
  return $res unless $res->{Ret} == 100;
  return $self->cmd_playback_download_start({
    Action    => "DownloadStart",
    StartTime => $file_rec->{'BeginTime'},
    EndTime   => $file_rec->{'EndTime'},
    Parameter => {
      FileName  => $file_rec->{'FileName'},
      PlayMode  => "ByName",
      TransMode => "TCP",
      Value     => 0
    }
  }, $self->_get_transcode_args($outname));
}

1;
