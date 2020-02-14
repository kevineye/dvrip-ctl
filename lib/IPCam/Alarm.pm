package IPCam::Alarm;
use Mojo::Base -base, -strict, -signatures, -async_await;

use Mojo::JSON 'encode_json';
use Mojo::Log;
use Mojo::UserAgent;

has camera => undef;
has stream => undef;
has name => "camera";

sub start($self) {
  $self->stream($self->camera->cmd_alarm_start);
  $self->stream->on(alarm => sub($, $a) {$self->alarm($a)});
}

sub alarm($self, $alarm) {
  die "not implemented";
}

1;
