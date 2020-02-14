package IPCam::Alarm::HomeAssistant;
use Mojo::Base 'IPCam::Alarm', -strict, -signatures, -async_await;

use Mojo::UserAgent;

has ha_token => undef;
has ha_url => undef;
has ha_sensor_name => sub($self) { my $n = lc $self->name; $n =~ s{[^a-z0-9]+}{_}; $n };
has ua => sub {Mojo::UserAgent->new->max_redirects(3)};

sub alarm($self, $alarm) {
  $self->ua->post_p(
    $self->ha_url . "/api/states/binary_sensor." . $self->ha_sensor_name,
    { authorization => "Bearer " . $self->ha_token },
    json => {
      state      => $alarm->{Status} eq 'Start' ? 'on' : 'off',
      attributes => {
        friendly_name => $self->name,
        device_class  => 'motion',
      }
    }
  );
}

1;
