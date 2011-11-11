package Devel::ebug::GDB::Plugin::Basic;
use strict;
use warnings;

sub register_commands {
  return (basic => \&basic);
}

sub basic {
  warn "loading basic plugin\n";
  my ($req, $context) = @_;
  return {
    codeline   => $context->{line},
    filename   => $context->{filename},
    finished   => $context->{finished},
    line       => $context->{line},
    package    => $context->{package},
    subroutine => subroutine($req, $context),
  };
}

sub subroutine {
  my ($req, $context) = @_;
  return '?';
}

1;
