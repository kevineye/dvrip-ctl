package IPCam::Alarm;
use Mojo::Base -base, -strict, -signatures, -async_await;

use Mojo::JSON 'encode_json';
use Mojo::Log;
use Mojo::UserAgent;
use Syntax::Keyword::Try;

has camera => undef;
has camera_name => "camera";
has stream => undef;
has name => "camera";
has last_on => 0;
has last_off => 0;
has reset_time => 0;
has is_on => 0;
has app => undef;
has log => sub($self) { $self->app ? $self->app->log : Mojo::Log->new};

our $types = {};

sub new_of_type($, $t, @opts) {
  $types->{$t}->new(@opts);
}

sub start($self) {
  $self->stream($self->camera->cmd_alarm_start);
  $self->stream->on(alarm => sub($, $a) {$self->_alarm($a)});
}

sub _alarm($self, $alarm) {
  try {
    my $t = time;
    if ($alarm->{Status} eq 'Start') {
      my $trigger = $t - $self->last_off > $self->reset_time;
      $self->last_on($t);
      if ($trigger) {
        $self->is_on(1);
        $self->alarm($alarm);
      }
    }
    else {
      $self->last_off($t);
      if ($self->is_on) {
        $self->is_on(0);
        $self->alarm($alarm);
      }
    }
  } catch {
    $self->log->error($@);
  }
}

sub alarm($self, $alarm) {
  die "not implemented";
}

1;
