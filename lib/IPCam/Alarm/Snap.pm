package IPCam::Alarm::Snap;
use Mojo::Base 'IPCam::Alarm', -strict, -signatures, -async_await;

use Digest::MD5 qw(md5 md5_hex);
use Mojo::File 'path';
use Time::Piece;

has snap_dir => 'public/snapshots';
has public_url_prefix => 'http://localhost/snapshots';
has secret => sub {md5(time)};
has format => sub {shift->motion ? 'gif' : 'jpg'};
has motion => 1;
has seconds => 10;
has ffmpeg => q{ffmpeg -loglevel panic -hide_banner -f h264 -i - -an -vf "setpts=0.125*PTS,scale='min(640,iw)':-1" -r 8 -y};

sub snap_url($self, $alarm = {}) {
  return $self->public_url_prefix . '/' . $self->snap_path($alarm);
}

sub snap_path($self, $alarm = {}) {
  my $t = $alarm->{StartTime}
    ? Time::Piece->strptime($alarm->{StartTime}, '%Y-%m-%d %T')
    : localtime;
  my $f = $t->datetime . '-' . md5_hex($self->secret . '+' . $t->epoch);
  return $self->camera_name . "/$f." . $self->format;
}

async sub alarm($self, $alarm) {
  if ($alarm->{Status} eq 'Start') {
    path($self->snap_dir . '/' . $self->camera_name)->make_path;
    my $f = $self->snap_dir . '/' . $self->snap_path($alarm);
    if ($self->motion) {
      await $self->camera->cmd_monitor(qq{|${\$self->ffmpeg} '$f'}, $self->seconds);
    } else {
      await $self->camera->cmd_snap($f) unless -e $f;
    }
    $self->log->debug("stored snapshot to $f");
    return $f;
  }
}

1;
