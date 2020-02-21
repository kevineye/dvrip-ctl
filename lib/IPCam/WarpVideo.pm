package IPCam::WarpVideo;
use Mojo::Base -base, -strict, -signatures, -async_await;

use Mojo::IOLoop::ProcBackground;
use Mojo::File 'path';
use Mojo::Log;
use Syntax::Keyword::Try;
use Time::Piece;

has camera => undef;
has name => undef;
has dir => sub { 'public/warp/' . shift->name };
has cron => '*/5 * * * *';
has hi_res => 1;
has join => 1;
has log => sub($self) { $self->app ? $self->app->log : Mojo::Log->new};
has app => undef;

sub start($self) {
  $self->app->plugin(Cron => {$self->cron => sub { $self->tick }});
}

sub _trunc($t) {
  Time::Piece->new($t->epoch - $t->hour*3600-$t->min*60-$t->sec);
}

async sub tick($self) {
  try {
    my $time = Time::Piece->new;
    await $self->snap($time);
    if ($self->join){#} and $time->minute < 1) {
      await $self->warp_day(_trunc($time));
      my $month_file = await $self->warp_month(_trunc($time));
      my $latest = sprintf "%s/latest.mp4", $self->dir;
      unlink $latest;
      my $latest_target = $month_file;
      substr($latest_target, 0, length($self->dir) + 1) = '' if substr($latest_target, 0, length $self->dir) eq $self->dir;
      symlink $latest_target => $latest;
    }
  } catch {
    $self->log->error($@);
  }
}

async sub snap($self, $time) {
  my $file = sprintf '%s/%04d/%02d/%02d-%02d%02d%02d.jpg', $self->dir, $time->year, $time->mon, $time->mday, $time->hour, $time->min, $time->sec;
  my $dir = sprintf '%s/%04d/%02d', $self->dir, $time->year, $time->mon;
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
  my $glob = sprintf '%s/%04d/%02d/%02d-*.jpg', $self->dir, $time->year, $time->mon, $time->mday;
  my $out = sprintf '%s/%04d/%02d/%02d.mp4', $self->dir, $time->year, $time->mon, $time->mday;
  my $p = Mojo::Promise->new;
  my $proc = Mojo::IOLoop::ProcBackground->new;
  $proc->on(dead => sub {
    $p->resolve($out)});
  $self->log->debug("warping daily photos to $out");
  $proc->run('</dev/null ' . join ' ', map { _shell_quote($_) } qw(ffmpeg -loglevel error -hide_banner -framerate 30 -pattern_type glob -i), $glob, qw(-c:v libx264 -pix_fmt yuv420p -y), $out);
  return $p;
}

async sub warp_month($self, $time) {
  my @files = glob sprintf '%s/%04d/%02d/*.mp4', $self->dir, $time->year, $time->mon;
  my $list = path(File::Temp->new(UNLINK => 0));
  $list->spurt(join '', map { "file '" . path($_)->to_abs . "'\n"} @files);
  my $out = sprintf '%s/%04d/%02d.mp4', $self->dir, $time->year, $time->mon;
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
