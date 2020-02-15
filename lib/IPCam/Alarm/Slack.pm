package IPCam::Alarm::Slack;
use Mojo::Base 'IPCam::Alarm', -strict, -signatures, -async_await;

use Mojo::UserAgent;

has slack_url => undef;
has ua => sub {Mojo::UserAgent->new->max_redirects(3)};

$IPCam::Alarm::types->{slack} = __PACKAGE__;

# TODO post picture
# TODO use chat.postMessage and chat.update to update message when mostion stops
# -- https://api.slack.com/methods/chat.postMessage
# -- https://api.slack.com/methods/chat.update

sub alarm($self, $alarm) {
  if ($alarm->{Status} eq 'Start') {
    $self->ua->post_p(
      $self->slack_url,
      json => { text => "Motion detected at " . $self->name }
    );
  }
}

1;
