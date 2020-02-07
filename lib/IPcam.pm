package IPcam;
use Mojo::Base -base, -strict, -signatures, -async_await;

# initially from https://github.com/667bdrm/sofiactl

use Digest::MD5 qw(md5 md5_hex);
use IO::Select;
use IO::Socket::INET;
use IO::Socket;
use Mojo::JSON qw(encode_json decode_json);
use Time::Local;
use Time::HiRes qw(usleep);

has client => sub {Mojo::IOLoop::Client->new};
has host => undef;
has port => 34567;
has user => 'admin';
has password => undef;
has sid => 0;
has sequence => 0;
has debug => 0;
has hashtype => 'md5based';

use constant {
  LOGIN_REQ1                     => 999,
  LOGIN_REQ2                     => 1000,
  LOGIN_RSP                      => 1000,
  LOGOUT_REQ                     => 1001,
  LOGOUT_RSP                     => 1002,
  FORCELOGOUT_REQ                => 1003,
  FORCELOGOUT_RSP                => 1004,
  KEEPALIVE_REQ                  => 1006, # 1005
  KEEPALIVE_RSP                  => 1007, # 1006

  SYSINFO_REQ                    => 1020,
  SYSINFO_RSP                    => 1021,

  CONFIG_SET                     => 1040,
  CONFIG_SET_RSP                 => 1041,
  CONFIG_GET                     => 1042,
  CONFIG_GET_RSP                 => 1043,
  DEFAULT_CONFIG_GET             => 1044,
  DEFAULT_CONFIG_GET_RSP         => 1045,
  CONFIG_CHANNELTILE_SET         => 1046,
  CONFIG_CHANNELTILE_SET_RSP     => 1047,
  CONFIG_CHANNELTILE_GET         => 1048,
  CONFIG_CHANNELTILE_GET_RSP     => 1049,
  CONFIG_CHANNELTILE_DOT_SET     => 1050,
  CONFIG_CHANNELTILE_DOT_SET_RSP => 1051,

  SYSTEM_DEBUG_REQ               => 1052,
  SYSTEM_DEBUG_RSP               => 1053,

  ABILITY_REQ                    => 1360,
  ABILITY_RSP                    => 1361,

  PTZ_REQ                        => 1400,
  PTZ_RSP                        => 1401,

  MONITOR_REQ                    => 1410,
  MONITOR_RSP                    => 1411,
  MONITOR_DATA                   => 1412,
  MONITOR_CLAIM                  => 1413,
  MONITOR_CLAIM_RSP              => 1414,

  PLAY_REQ                       => 1420,
  PLAY_RSP                       => 1421,
  PLAY_DATA                      => 1422,
  PLAY_EOF                       => 1423,
  PLAY_CLAIM                     => 1424,
  PLAY_CLAIM_RSP                 => 1425,
  DOWNLOAD_DATA                  => 1426,

  TALK_REQ                       => 1430,
  TALK_RSP                       => 1431,
  TALK_CU_PU_DATA                => 1432,
  TALK_PU_CU_DATA                => 1433,
  TALK_CLAIM                     => 1434,
  TALK_CLAIM_RSP                 => 1435,

  FILESEARCH_REQ                 => 1440,
  FILESEARCH_RSP                 => 1441,
  LOGSEARCH_REQ                  => 1442,
  LOGSEARCH_RSP                  => 1443,
  FILESEARCH_BYTIME_REQ          => 1444,
  FILESEARCH_BYTIME_RSP          => 1445,

  SYSMANAGER_REQ                 => 1450,
  SYSMANAGER_RSP                 => 1451,
  TIMEQUERY_REQ                  => 1452,
  TIMEQUERY_RSP                  => 1453,

  DISKMANAGER_REQ                => 1460,
  DISKMANAGER_RSP                => 1461,

  FULLAUTHORITYLIST_GET          => 1470,
  FULLAUTHORITYLIST_GET_RSP      => 1471,
  USERS_GET                      => 1472,
  USERS_GET_RSP                  => 1473,
  GROUPS_GET                     => 1474,
  GROUPS_GET_RSP                 => 1475,
  ADDGROUP_REQ                   => 1476,
  ADDGROUP_RSP                   => 1477,
  MODIFYGROUP_REQ                => 1478,
  MODIFYGROUP_RSP                => 1479,
  DELETEGROUP_REQ                => 1480,
  DELETEGROUP_RSP                => 1481,
  ADDUSER_REQ                    => 1482,
  ADDUSER_RSP                    => 1483,
  MODIFYUSER_REQ                 => 1484,
  MODIFYUSER_RSP                 => 1485,
  DELETEUSER_REQ                 => 1486,
  DELETEUSER_RSP                 => 1487,
  MODIFYPASSWORD_REQ             => 1488,
  MODIFYPASSWORD_RSP             => 1489,

  GUARD_REQ                      => 1500,
  GUARD_RSP                      => 1501,
  UNGUARD_REQ                    => 1502,
  UNGUARD_RSP                    => 1503,
  ALARM_REQ                      => 1504,
  ALARM_RSP                      => 1505,
  NET_ALARM_REQ                  => 1506,
  NET_ALARM_REQ                  => 1507,
  ALARMCENTER_MSG_REQ            => 1508,

  UPGRADE_REQ                    => 1520,
  UPGRADE_RSP                    => 1521,
  UPGRADE_DATA                   => 1522,
  UPGRADE_DATA_RSP               => 1523,
  UPGRADE_PROGRESS               => 1524,
  UPGRADE_INFO_REQ               => 1525,
  UPGRADE_INFO_RSQ               => 1526,

  IPSEARCH_REQ                   => 1530,
  IPSEARCH_RSP                   => 1531,
  IP_SET_REQ                     => 1532,
  IP_SET_RSP                     => 1533,

  CONFIG_IMPORT_REQ              => 1540,
  CONFIG_IMPORT_RSP              => 1541,
  CONFIG_EXPORT_REQ              => 1542,
  CONFIG_EXPORT_RSP              => 1543,
  LOG_EXPORT_REQ                 => 1544, #CONDIG_EXPORT_REQ
  LOG_EXPORT_RSP                 => 1545, #CONFIG_EXPORT_RSP

  NET_KEYBOARD_REQ               => 1550,
  NET_KEYBOARD_RSP               => 1551,

  NET_SNAP_REQ                   => 1560,
  NET_SNAP_RSP                   => 1561,
  SET_IFRAME_REQ                 => 1562,
  SET_IFRAME_RSP                 => 1563,

  RS232_READ_REQ                 => 1570,
  RS232_READ_RSP                 => 1571,
  RS232_WRITE_REQ                => 1572,
  RS232_WRITE_RSP                => 1573,
  RS485_READ_REQ                 => 1574,
  RS485_READ_RSP                 => 1575,
  RS485_WRITE_REQ                => 1576,
  RS485_WRITE_RSP                => 1577,
  TRANSPARENT_COMM_REQ           => 1578,
  TRANSPARENT_COMM_RSP           => 1579,
  RS485_TRANSPARENT_DATA_REQ     => 1580,
  RS485_TRANSPARENT_DATA_RSP     => 1581,
  RS232_TRANSPARENT_DATA_REQ     => 1582,
  RS232_TRANSPARENT_DATA_RSP     => 1583,

  SYNC_TIME_REQ                  => 1590,
  SYNC_TIME_RSP                  => 1591,

  PHOTO_GET_REQ                  => 1600,
  PHOTO_GET_RSP                  => 1601,

  ERROR_CODES                    => {
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
  }
};

sub new($class, @opts) {
  my $self = $class->SUPER::new(@opts);
  # $self->client->connect(address => $self->host, port => $self->port)
  #   or die "Cannot connect to camera at ${\$self->host}:${\$self->port}\n";
  $self->{socket} ||= IO::Socket::INET->new(
    PeerAddr => $self->host,
    PeerPort => $self->port,
    Proto    => 'tcp',
    Timeout  => 10000,
    Type     => SOCK_STREAM,
    Blocking => 1
  ) or die "Cannot connect to camera at $self->{host}:$self->{port}\n";
  return $self;
}

sub _build_packet_sid($self) {
  return $self->_format_hex($self->sid);
}

sub _format_hex($self, $value) {
  return sprintf("0x%08x", $value);
}

sub build_packet($self, $type, $params) {
  my @pkt_prefix_1;
  my $pkt_type;

  @pkt_prefix_1 = (0xff, 0x00, 0x00, 0x00); # (head_flag, version (was 0x01), reserved01, reserved02)
  my $pkt_prefix_2 = 0x00;                  # (total_packets, cur_packet)

  $pkt_type = $type;

  if ($pkt_type eq FULLAUTHORITYLIST_GET) {
    $pkt_prefix_2 = 0x16;
  }
  elsif ($pkt_type eq DELETEUSER_REQ) {
    $pkt_prefix_2 = 0x06;
  }
  elsif ($pkt_type eq LOGSEARCH_REQ) {
    $pkt_prefix_2 = 0x22;
  }
  elsif ($pkt_type eq CONFIG_CHANNELTILE_SET) {
    $pkt_prefix_2 = 0xa2;
  }
  elsif ($pkt_type eq CONFIG_SET) {
    $pkt_prefix_2 = 0xae;
  }

  my $msgid = pack('s', 0) . pack('s', $pkt_type);

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

sub get_reply_head($self) {
  my $data;
  my @reply_head_array;

  # head_flag, version, reserved
  $self->{socket}->recv($data, 4); # TODO

  my @header = unpack('C*', $data);

  my ($head_flag, $version, $reserved01, $reserved02) =
    (@header)[ 0, 1, 2, 3 ];

  # int sid, int seq
  $self->{socket}->recv($data, 8); # TODO

  my ($sid, $seq) = unpack('i*', $data);

  $reply_head_array[3] = ();

  $self->{socket}->recv($data, 8); # TODO
  my ($channel, $endflag, $msgid, $size) = unpack('CCSI', $data);

  my $reply_head = {
    Version        => $version,
    SessionID      => $sid,
    Sequence       => $seq,
    MessageId      => $msgid,
    Content_Length => $size,
    Channel        => $channel,
    EndFlag        => $endflag,
  };

  $self->sid($sid);
  return $reply_head;
}

sub get_reply_data($self, $reply) {
  my $length = $reply->{'Content_Length'};
  my $out;

  do {
    $self->{socket}->recv(my $data, $length) // die "recv: $!"; # TODO
    $length -= length $data;
    $out .= $data;
  } while ($length > 0);

  return $out;
}

sub prepare_generic_command_head($self, $msgid, $parameters) {
  my $pkt = $parameters;

  if ($msgid ne LOGIN_REQ2 and defined $parameters) {
    $parameters->{SessionID} = $self->_build_packet_sid();
  }

  if ($msgid eq MONITOR_REQ) {
    $parameters->{SessionID} = sprintf("0x%02X", $self->sid);
  }

  my $cmd_data = $self->build_packet($msgid, $pkt);

  $self->{socket}->send($cmd_data); # TODO
  my $reply_head = $self->get_reply_head();
  return $reply_head;
}

sub prepare_generic_command($self, $msgid, $parameters) {
  my $reply_head = $self->prepare_generic_command_head($msgid, $parameters);
  my $out = $self->get_reply_data($reply_head);

  if ($out) {
    my $json;
    # trim off garbage at line ending
    $out =~ s/([\x00-\x20]*)\Z//ms;

    eval {
      # code that might throw exception
      $json = decode_json($out);
    };
    if ($@) {
      # report the exception and do something about it
      print "decode_json exception. data:" . $out . "\n";
    }

    my $code = $json->{'Ret'};

    if (defined($code)) {
      if (defined(ERROR_CODES->{$code})) {
        $json->{'RetMessage'} = ERROR_CODES->{$code};
      }
    }

    return $json;
  }
  return undef;
}

sub prepare_generic_file_download_command($self, $msgid, $parameters, $file) {
  my $reply_head = $self->prepare_generic_command_head($msgid, $parameters);
  my $out = $self->get_reply_data($reply_head);

  open(my $fh, ">$file");
  print $fh $out;
  close $fh;

  return 1;
}

sub _md5_hash($self, $message) {
  my $hash = '';
  my $msg_md5 = md5($message);

  if ($self->debug != 0) {
    print md5_hex($message) . "\n";
  }

  my @hash = unpack('C*', $msg_md5);

  if ($self->debug != 0) {
    for my $chr (@hash) {
      print sprintf("%02x ", $chr);
    }

    print "\n";
  }

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

    if ($self->debug != 0) {
      print "$n\n";
    }

    $hash .= chr($n);
  }

  if ($self->debug != 0) {
    print "hash = $hash\n";
  }

  return $hash;
}

sub _plain_hash($self, $message) {
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

sub cmd_login($self) {
  my $pkt = {
    EncryptType => "MD5",
    LoginType   => "DVRIP-Web",
    PassWord    => $self->_make_hash($self->password),
    UserName    => $self->user
  };
  my $reply_json = $self->prepare_generic_command(LOGIN_REQ2, $pkt);
  return $reply_json;
}

sub cmd_system_info($self) {
  my $pkt = { Name => 'SystemInfo', };
  my $systeminfo = $self->prepare_generic_command(SYSINFO_REQ, $pkt);
  return $systeminfo;
}

sub cmd_alarm_info($self, $parameters) {
  my $pkt = {
    Name      => 'AlarmInfo',
    AlarmInfo => $parameters,
  };
  return $self->prepare_generic_command(ALARM_REQ, $pkt);
}

sub cmd_net_alarm($self) {
  my $pkt = {
    Name         => 'OPNetAlarm',
    NetAlarmInfo => {
      Event => 0,
      State => 1,
    },
  };
  return $self->prepare_generic_command(NET_ALARM_REQ, $pkt);
}

sub cmd_alarm_center_message($self) {
  my $pkt = {
    Name              => 'NetAlarmCenter',
    NetAlarmCenterMsg => {
      Address   => "0x0B0A060A",
      Channel   => 0,
      Descrip   => "",
      Event     => "MotionDetect",
      SerialID  => "003344236523",
      StartTime => "2010-06-24 17:04:22",
      Status    => "Stop",
      Type      => "Alarm",
    },
  };

  my $cmd_data = $self->build_packet(ALARMCENTER_MSG_REQ, $pkt);

  $self->{socket}->send($cmd_data); # TODO
  my $reply_head = $self->get_reply_head();
  my $out = $self->get_reply_data($reply_head);
  # trim off garbage at line ending
  $out =~ s/([\x00-\x20]*)\Z//ms;
  return decode_json($out);
}

sub cmd_net_keyboard($self, $parameters) {
  my $pkt = {
    Name          => 'OPNetKeyboard',
    OPNetKeyboard => $parameters,
  };
  return $self->prepare_generic_command(NET_KEYBOARD_REQ, $pkt);
}

sub cmd_users($self) {
  return $self->prepare_generic_command(USERS_GET, {});
}

sub cmd_groups($self) {
  return $self->prepare_generic_command(GROUPS_GET, {});
}

sub cmd_storage_info($self) {
  my $pkt = { Name => 'StorageInfo' };
  return $self->prepare_generic_command(SYSINFO_REQ, $pkt);
}

sub cmd_work_state($self) {
  my $pkt = { Name => 'WorkState', };
  return $self->prepare_generic_command(SYSINFO_REQ, $pkt);
}

sub cmd_snap($self, $out) {
  my $pkt = { Name => 'OPSNAP' };
  return $self->prepare_generic_file_download_command(NET_SNAP_REQ, $pkt, $out);
}

sub cmd_empty($self) {
  my $pkt = { Name => '' };
  return $self->prepare_generic_command(SYSINFO_REQ, $pkt);
}

sub cmd_keepalive($self) {
  my $pkt = { Name => 'KeepAlive' };
  return $self->prepare_generic_command(KEEPALIVE_REQ, $pkt);
}

sub cmd_monitor_claim($self) {
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
  return $self->prepare_generic_command(MONITOR_CLAIM, $pkt);
}

sub cmd_monitor_stop($self) {
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
  my $cmd_data = $self->build_packet(MONITOR_REQ, $pkt);
  $self->{socket}->send($cmd_data); # TODO

  my $reply = $self->get_reply_head();

  for my $k (keys %{$reply}) {
    print "rh = $k\n";
  }

  my $out = $self->get_reply_data($reply);
  # trim off garbage at line ending
  $out =~ s/([\x00-\x20]*)\Z//ms;
  my $out1 = decode_json($out);

  return $out1;
}

sub cmd_monitor_start($self, $file, $mode) {
  $mode ||= '>';

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

  my $cmd_data = $self->build_packet(MONITOR_REQ, $pkt);
  $self->{socket}->send($cmd_data); # TODO

  open my ($fh), $mode, $file;

  my $stop = 0;
  while (defined(my $reply = $self->get_reply_head()) and $stop == 0) {
    print $fh $self->get_reply_data($reply);
  }

  close $fh;
  return 1;
}

sub cmd_set_time($self, $nortc) {
  my ($sec, $min, $hour, $mday, $mon, $year) = localtime();

  my $clock_cmd = 'OPTimeSetting';

  my $pkt_type = SYSMANAGER_REQ;

  if ($nortc) {
    $clock_cmd .= 'NoRTC';
    $pkt_type = SYNC_TIME_REQ;
  }

  my $pkt = {
    Name         => $clock_cmd,
    SessionID    => $self->_build_packet_sid(),
    "$clock_cmd" => sprintf(
      "%4d-%02d-%02d %02d:%02d:%02d",
      $year + 1900,
      $mon + 1, $mday, $hour, $min, $sec
    )
  };

  my $cmd_data = $self->build_packet($pkt_type, $pkt);

  $self->{socket}->send($cmd_data); # TODO
  my $reply = $self->get_reply_head();
  my $out = $self->get_reply_data($reply);

  if ($out) {
    # trim off garbage at line ending
    $out =~ s/([\x00-\x20]*)\Z//ms;
    return decode_json($out);
  }

  return undef;
}

sub cmd_system_function($self) {
  my $pkt = { Name => 'SystemFunction' };
  return $self->prepare_generic_command(ABILITY_REQ, $pkt);
}

sub cmd_file_query($self, $parameters) {
  my $pkt = {
    Name        => 'OPFileQuery',
    OPFileQuery => $parameters,
  };
  return $self->prepare_generic_command(FILESEARCH_REQ, $pkt);
}

sub cmd_oem_info($self) {
  my $pkt = { Name => 'OEMInfo' };
  return $self->prepare_generic_command(SYSINFO_REQ, $pkt);
}

sub cmd_playback($self, $parameters) {
  my $pkt = {
    Name       => 'OPPlayBack',
    OPPlayBack => $parameters,
  };
  return $self->prepare_generic_command(PLAY_CLAIM, $pkt);
}

sub cmd_playback_download_start($self, $parameters, $file, $mode) {
  my $pkt = {
    Name       => 'OPPlayBack',
    OPPlayBack => $parameters,
  };

  my $reply_head = $self->prepare_generic_command_head(PLAY_REQ, $pkt);
  open my ($fh), $mode, $file;
  do {
    print $fh $self->get_reply_data($reply_head);
    $reply_head = $self->get_reply_head();
  } while ($reply_head->{'Content_Length'} > 0 && $reply_head->{'MessageId'} == DOWNLOAD_DATA);
  close $fh;
}

sub cmd_log_query($self, $parameters) {
  my $pkt = {
    Name       => 'OPLogQuery',
    OPLogQuery => $parameters,
  };
  return $self->prepare_generic_command(LOGSEARCH_REQ, $pkt);
}

sub cmd_export_log($self, $file) {
  my $pkt = { Name => '' };
  return $self->prepare_generic_file_download_command(LOG_EXPORT_REQ, $pkt, $file);
}

sub cmd_export_config($self, $file) {
  my $pkt = { Name => '' };
  return $self->prepare_generic_file_download_command(CONFIG_EXPORT_REQ, $pkt, $file);
}

sub cmd_storage_manager($self, $parameters) {
  my $pkt = {
    Name             => 'OPStorageManager',
    OPStorageManager => $parameters,
    SessionID        => $self->_build_packet_sid(),
  };
  return $self->prepare_generic_command(DISKMANAGER_REQ, $pkt);
}

sub cmd_config_get($self, $parameters) {
  my $pkt = { Name => $parameters };
  return $self->prepare_generic_command(CONFIG_GET, $pkt);
}

sub cmd_config_set($self, $name, $value) {
  my $pkt = { Name => $name, $name => $value };
  return $self->prepare_generic_command(CONFIG_SET, $pkt);
}

sub cmd_ptz_control($self, $parameters) {
  my $pkt = { Name => 'OPPTZControl', OPPTZControl => $parameters };
  return $self->prepare_generic_command(PTZ_REQ, $pkt);
}

sub cmd_ptz($self, $direction, $ms) {
  $direction ||= 'left';
  $direction = "Direction" . ucfirst(lc($direction)) unless $direction =~ /^[A-Z]/;
  $ms ||= 500;
  my $remainder = 0;
  if ($ms > 9000) {
    $remainder = $ms - 9000;
    $ms = 9000;
  }
  my $res = $self->cmd_ptz_control({
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
  usleep($ms * 1000);
  $res = $self->cmd_ptz_control({
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
  });
  if ($remainder > 0 && $res->{Ret} == 100) {
    return $self->cmd_ptz($direction, $remainder);
  }
  else {
    return $res;
  }
}

sub cmd_ptz_set_preset($self, $preset) {
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
      "Preset"   => $preset + 0 // 0,
      "Step"     => 10,
      "Tour"     => 0,
    }
  });
}

sub cmd_ptz_goto_preset($self, $preset) {
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
      "Preset"   => $preset + 0 // 0,
      "Step"     => 10,
      "Tour"     => 0,
    }
  });
}

sub cmd_ptz_abs($self, $x, $y) {
  $self->cmd_ptz(up => 5000);
  $self->cmd_ptz(left => 27000);
  $self->cmd_ptz(right => $x || 0);
  $self->cmd_ptz(down => $y || 0);
}

sub cmd_alarm_start($self, $cb) {
  $cb ||= sub {print encode_json($_[1]) . "\n"};

  my $pkt = {
    Name      => '',
    SessionID => $self->_build_packet_sid(),
  };

  my $res = $self->prepare_generic_command(GUARD_REQ, $pkt);
  return $res unless $res->{Ret} == 100;

  # wait for alarms
  my $select = IO::Select->new;
  $select->add($self->{socket});
  while (1) {
    $! = 0;
    my @ready = $select->can_read(20); # TODO
    last if $!;
    if (@ready) {
      my $reply_head = $self->get_reply_head();
      my $out = $self->get_reply_data($reply_head);
      # trim off garbage at line ending
      $out =~ s/([\x00-\x20]*)\Z//ms;
      $cb->($self, decode_json($out)->{AlarmInfo});
    }
    $self->cmd_keepalive;
  }
}

sub _get_transcode_args($self, $file, $seconds) {
  $file ||= 'out.h264';
  my $mode = '>';
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

sub cmd_monitor($self, $file, $seconds) {
  my $res = $self->cmd_monitor_claim;
  return $res unless $res->{Ret} == 100;
  return $self->cmd_monitor_start($self->_get_transcode_args($file, $seconds));
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

sub cmd_ls($self, $begin, $end) {
  $begin = $self->_parse_relative_time($begin // 3600);
  $end = $self->_parse_relative_time($end // 0);
  my $res = $self->cmd_file_query({
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
  return $res->{OPFileQuery};
}

sub cmd_download($self, $file_rec, $outname) {
  $outname ||= 'out.h264';
  my $res = $self->cmd_playback({
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
