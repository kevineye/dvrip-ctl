package IPCam::Alarm::Slack;
use Mojo::Base 'IPCam::Alarm::Snap', -strict, -signatures, -async_await;

use Mojo::UserAgent;

has slack_url => undef;
has ua => sub {Mojo::UserAgent->new->max_redirects(3)};

$IPCam::Alarm::types->{slack} = __PACKAGE__;

# TODO use chat.postMessage and chat.update to update message when motion stops
# -- https://api.slack.com/methods/chat.postMessage
# -- https://api.slack.com/methods/chat.update

async sub alarm($self, $alarm) {
  await $self->SUPER::alarm($alarm);
  if ($alarm->{Status} eq 'Start') {
    my $message = "Motion detected at " . $self->name;
    $self->ua->post_p(
      $self->slack_url,
      json => {
        text   => $message,
        blocks => [
          {
            type      => "image",
            title     => {
              type  => "plain_text",
              text  => $message,
              emoji => Mojo::JSON->true,
            },
            image_url => $self->snap_url($alarm),
            alt_text  => $message,
          }
        ]
      }
    );
  }
}

1;
