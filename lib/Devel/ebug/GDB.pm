package Devel::ebug::GDB;
use strict;
use warnings;
use IO::Socket::INET;
use String::Koremutake;
use YAML::Syck;
use Devel::GDB;
use Module::Pluggable
  search_path => 'Devel::ebug::GDB::Plugin',
  require     => 1;


my $context = {
  finished     => 0,
  initialise   => 1,
  mode         => "step",
  stack        => [],
  watch_points => [],

  codeline   => 0,
  filename   => 'nowhere',
  finished   => 0,
  line       => 0,
  package    => 'Nowhere',
};

# Commands that the back end can respond to
# Set record if the command changes start and should thus be recorded
# in order for undo to work properly


my %commands = (
    ping => \&ping
);

sub initialise {
  my ($program) = @_;
  my $k      = String::Koremutake->new;
  my $int    = $k->koremutake_to_integer($ENV{SECRET});
  my $port   = 3141 + ($int % 1024);
  my $server = IO::Socket::INET->new(
    Listen    => 5,
    LocalAddr => 'localhost',
    LocalPort => $port,
    Proto     => 'tcp',
    ReuseAddr => 1,
    Reuse     => 1,
    )
    || die $!;

  foreach my $plugin (__PACKAGE__->plugins) {
    my $sub = $plugin->can("register_commands");
    next unless $sub;
    my %new = &$sub;
    foreach my $command (keys %new) {
#      warn "registering $command";
      $commands{$command} = $new{$command};
    }
  }

  $context->{socket} = $server->accept;

  my $gdb = new Devel::GDB(-params=>["-q"]);
  my $file = $gdb->get("file $program"); # TODO: quote
  warn $file;
  loop();

}
sub loop {
    while (1) {
        my $req     = get();
        my $command = $req->{command};
        my $sub = $commands{$command};
        if (defined $sub) {
          put($sub->($req, $context));
        } else {
            die "unknown command $command";
        }
    }
}

sub put {
  my ($res) = @_;
  my $data = unpack("h*", Dump($res));
  $context->{socket}->print($data . "\n");
}

sub get {
  exit unless $context->{socket};
  my $data = $context->{socket}->getline;
  my $req = Load(pack("h*", $data));
  return $req;
}

initialise(@ARGV);

sub ping {
  my($req, $context) = @_;
  my $secret = $ENV{SECRET};
  die "Did not pass secret" unless $req->{secret} eq $secret;
  $ENV{SECRET} = "";
  return {
    version => 0.52,
  }
}

1;

