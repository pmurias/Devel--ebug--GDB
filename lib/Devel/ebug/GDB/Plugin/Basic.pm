package Devel::ebug::GDB::Plugin::Basic;
use strict;
use warnings;

sub register_commands {
    return ( basic => \&basic );
}

sub basic {
    my ( $req, $context ) = @_;
    return {
        codeline   => $context->codeline,
        filename   => $context->filename,
        finished   => $context->finished,
        line       => $context->line,
        package    => $context->package,
        subroutine => $context->subroutine
    };
}

1;
