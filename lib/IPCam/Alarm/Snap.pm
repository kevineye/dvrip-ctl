package IPCam::Alarm::Snap;
use Mojo::Base 'IPCam::Alarm', -strict, -signatures, -async_await;

use Digest::MD5 qw(md5 md5_hex);
use Mojo::File 'path';
use Time::Piece;

has snap_dir => 'public/snapshots';
has public_url_prefix => 'http://localhost/snapshots';
has secret => sub { md5(time) };

sub snap_url($self, $alarm = {}) {
  return $self->public_url_prefix . '/' . $self->snap_path;
}

sub snap_path($self, $alarm = {}) {
  my $t = $alarm->{StartTime}
    ? Time::Piece->strptime('%Y-%m-%d %T')
    : localtime;
  my $f = $t->datetime . '-' . md5_hex($self->secret . '+' . $t->epoch);
  return $self->camera_name . "/$f.jpg";
}

async sub alarm($self, $alarm) {
  if ($alarm->{Status} eq 'Start') {
    path($self->snap_dir . '/' . $self->camera_name)->make_path;
    my $f = $self->snap_dir . '/' . $self->snap_path;
    await $self->camera->cmd_snap($f) unless -e $f;
    $self->log->debug("stored snapshot to $f");
    return $f;
  }
}

1;
