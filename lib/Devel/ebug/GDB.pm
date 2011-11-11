package Devel::ebug::GDB;
use strict;
use warnings;
use Moo;
use IO::Socket::INET;
use String::Koremutake;
use YAML::Syck;
use Devel::GDB;
use Module::Pluggable
  search_path => 'Devel::ebug::GDB::Plugin',
  require     => 1;

###### GDB independent part

has socket=>(is=>'rw');
has commands=>(is=>'ro',default=>sub {{}});

sub loop {
    my ($self) = @_;
    while (1) {
        my $req     = $self->get();
        my $command = $req->{command};
        my $sub = $self->commands->{$command};
        if (defined $sub) {
          $self->put($sub->($req, $self));
        } else {
            die "unknown command $command";
        }
    }
}

sub put {
  my ($self,$res) = @_;
  my $data = unpack("h*", Dump($res));
  $self->socket->print($data . "\n");
}

sub get {
  my ($self) = @_;
  exit unless $self->socket; # TODO: better error handling
  my $data = $self->socket->getline;
  my $req = Load(pack("h*", $data));
  return $req;
}

sub ping {
  my($self,$req) = @_;
  my $secret = $ENV{SECRET};
  die "Did not pass secret" unless $req->{secret} eq $secret;
  $ENV{SECRET} = "";
  return {
    version => 0.52,
  }
}

sub socket_accept {
  my ($self) = @_;
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
    $server->accept;
}

###########################

has program=>(is=>'ro');

has finished=>(is=>'rw',default=>sub {0});
has line=>(is=>'rw');
has filename=>(is=>'rw',default=>sub {'?'});
has package=>(is=>'rw',default=>sub {'?'});
has subroutine=>(is=>'rw',default=>sub {'?'});

has codeline=>(is=>'rw',default=>sub {'?'});

has gdb=>(is=>'rw');

sub get_pos {
    my ($self) = @_;
    my $bt = $self->gdb->get("bt 1");
    $bt =~ m/
        \#\d+ \s+
        (\w+) \s+
        \(\) \s+
        at \s+ 
        (.*):(\d+)
    /x;
    $self->subroutine($1);
    $self->filename($2);
    $self->line($3);
}

sub register_plugins {
  my ($self) = @_;
  foreach my $plugin (__PACKAGE__->plugins) {
    my $sub = $plugin->can("register_commands");
    next unless $sub;
    my %new = &$sub;
    foreach my $command (keys %new) {
      $self->commands->{$command} = $new{$command};
    }
  }
}

sub BUILD {
    my ($self) = @_;
    $self->commands->{ping} = sub {$self->ping(@_)};
    $self->register_plugins();
}
sub start {
    my ($self) = @_;
    $self->socket($self->socket_accept);
    $self->start_gdb();
}

sub start_gdb {
  my ($self) = @_;
  $self->gdb(new Devel::GDB(-params=>["-q"]));
  my $file = $self->gdb->get("file ".$self->program); # TODO: quote

  $self->gdb->get("start");

  $self->get_pos();


  $self->loop();
}

1;

