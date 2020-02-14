package IPCam::Alarm::Log;
use Mojo::Base -base, -strict, -signatures, -async_await;

use Mojo::JSON 'encode_json';
use Mojo::Log;

has camera => undef;
has log => sub {Mojo::Log->new};
has stream => undef;

sub start($self) {
  $self->stream($self->camera->cmd_alarm_start);
  $self->stream->on(alarm => sub ($, $a){ $self->alarm($a) });
}

sub alarm($self, $alarm) {
  $self->log->info(encode_json $alarm);
}

1;
