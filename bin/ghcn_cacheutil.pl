#!/usr/bin/perl
# ghcn_cacheutil.pl - Report temperature extremes from ghcn_fetch.pl output

use v5.18;  # minimum for Object::Pad

our $VERSION = 'v0.0.000';

use Weather::GHCN::App::CacheUtil;

Weather::GHCN::App::CacheUtil->run( \@ARGV );

########################################################################
# Documentation
########################################################################
__END__

=head1 NAME

ghcn_cacheutil.pl - Report temperature extremes from ghcn_fetch.pl output

=head1 SYNOPSIS

    ghcn_cacheutil.pl -location <dir> -clean -show

    ghcn_cacheutil.pl [--help | -? | --usage]

=head1 DESCRIPTION



=head1 PARAMETERS

Getoptions::Long is used, so either - or -- may be used.  Parameter
names may be abbreviated, so long as they remains unambiguous.  Flag
options may appear after filenames.

=over 4

=item -location <dir>


=item -clean


=item -show


=item -h | -help

Display this documentation.

=back

=head1 AUTHOR

Gary Puckering (jgpuckering@rogers.com)

=head1 LICENSE AND COPYRIGHT

Copyright 2022, Gary Puckering

=cut
