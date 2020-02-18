package IPCam::WarpVideo;
use Mojo::Base -base, -strict, -signatures, -async_await;

use Mojo::IOLoop::ProcBackground;
use Mojo::File 'path';
use Mojo::Log;

has camera => undef;
has name => undef;
has dir => sub { 'public/warp/' . shift->name };
has interval => 300;
has log => sub {Mojo::Log->new};
has hi_res => 1;
has join => 1;

sub start($self) {
  Mojo::IOLoop->recurring($self->interval => sub { $self->tick });
  $self->tick;
}

async sub tick($self) {
  eval {
    await $self->snap;
    my $time = time;
    my @l = localtime;
    if ($self->join and $l[1] * 60 + $l[0] < $self->interval) {
      await $self->warp_day($time - $self->interval) ;
      my $month_file = await $self->warp_month($time - $self->interval);
      my $latest = sprintf "%s/latest.mp4", $self->dir;
      unlink $latest;
      my $latest_target = $month_file;
      substr($latest_target, 0, length($self->dir)+1) = '' if substr($latest_target, 0, length $self->dir) eq $self->dir;
      symlink $latest_target => $latest;
    }
  };
  if ($@) {
    $self->log->error($@);
  }
}

async sub snap($self) {
  my @l = localtime;
  my $file = sprintf '%s/%04d/%02d/%02d-%02d%02d%02d.jpg', $self->dir, $l[5]+1900, $l[4]+1, @l[3,2,1,0];
  my $dir = sprintf '%s/%04d/%02d', $self->dir, $l[5]+1900, $l[4]+1;
  path($dir)->make_path;
  $self->log->debug("snapping $file");
  if ($self->hi_res) {
    await $self->camera->cmd_monitor($file, 0.1);
  } else {
    await $self->camera->cmd_snap($file);
  }
  return $file;
}

async sub warp_day($self, $time) {
  my @l = localtime $time;
  my $glob = sprintf '%s/%04d/%02d/%02d-*.jpg', $self->dir, $l[5]+1900, $l[4]+1, $l[3];
  my $out = sprintf '%s/%04d/%02d/%02d.mp4', $self->dir, $l[5]+1900, $l[4]+1, $l[3];
  my $p = Mojo::Promise->new;
  my $proc = Mojo::IOLoop::ProcBackground->new;
  $proc->on(dead => sub {
    $p->resolve($out)});
  $self->log->debug("warping daily photos to $out");
  $proc->run('</dev/null ' . join ' ', map { _shell_quote($_) } qw(ffmpeg -loglevel error -hide_banner -framerate 30 -pattern_type glob -i), $glob, qw(-c:v libx264 -pix_fmt yuv420p -y), $out);
  return $p;
}

async sub warp_month($self, $time) {
  my @l = localtime $time;
  my @files = glob sprintf '%s/%04d/%02d/*.mp4', $self->dir, $l[5]+1900, $l[4]+1;
  my $list = path(File::Temp->new(UNLINK => 0));
  $list->spurt(join '', map { "file '" . path($_)->to_abs . "'\n"} @files);
  my $out = sprintf '%s/%04d/%02d.mp4', $self->dir, $l[5]+1900, $l[4]+1;
  my $p = Mojo::Promise->new;
  my $proc = Mojo::IOLoop::ProcBackground->new;
  $proc->on(dead => sub {
    $list->remove;
    $p->resolve($out)});
  $self->log->info("warping month to $out");
  $proc->run('</dev/null ' . join ' ', map { _shell_quote($_) } qw(ffmpeg -loglevel error -hide_banner -f concat -safe 0 -i), $list, qw(-c copy -y), $out);
  return $p;
}

sub _shell_quote($arg) {
  if ($arg =~ /\A\w+\z/) {
    return $arg;
  }
  $arg =~ s/'/'"'"'/g;
  return "'$arg'";
}

1;
