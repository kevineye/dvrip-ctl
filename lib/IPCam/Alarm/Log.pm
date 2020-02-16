package IPCam::Alarm::Log;
use Mojo::Base 'IPCam::Alarm', -strict, -signatures, -async_await;

use Mojo::JSON 'encode_json';

$IPCam::Alarm::types->{log} = __PACKAGE__;

sub alarm($self, $alarm) {
  $self->log->info($self->name . " ==> " . encode_json $alarm);
}

1;
