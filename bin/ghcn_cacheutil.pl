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

    ghcn_cacheutil.pl [-location <dir>] [-couuntry <str>] [-state <str>]
                      [-remove] [-cachedir <dir>] [-profile <file>] [-outclip]

    ghcn_cacheutil.pl [--help | -? | --usage]

=head1 DESCRIPTION



=head1 PARAMETERS

Getoptions::Long is used, so either - or -- may be used.  Parameter
names may be abbreviated, so long as they remains unambiguous.  Flag
options may appear after filenames.

=over 4

=item -country <str>

Filter the station list to include only those from a specific
country.  The string can be a 2-character GEC (formerly FIPS)
country code, a 3-character UN country code, or a 3-character
internet country code (including the dot).  Longer strings are
treated as a pattern and matched (unanchored) against country names.

=item -state <str> (or -province)

Filter the station list to include only those within the specified
2-character US state or Canadian province code.

=item -location <str>

Filter the station list to include only those whose name matches the
specified pattern.  For a starts-with match, prefix the pattern with
^ (or \A).  For an ends-with match, suffix the pattern with $ (or \Z).

You can also specify a station id (e.g. CA006105978) or a
comma-delimited list of station id's (e.g. CA006105978,USC00336346).

As a handy shortcut, mappings between user-defined names and a station
id or id list can be defined in the locations section of .ghcn_fetch.yaml.

=item -remove

Remove the listed items from the cache, with the exception of items that
correspond to aliases in the user profile.

=item -cachedir <dir>

This section defines the location of the cache directory where pages 
fetched from the NOAA GHCN repository will be saved, in accordance 
with your -refresh option. Using a cache vastly improves the 
performance of subsequent invocations of B<ghcn_fetch>, especially when 
using the same station filtering criteria.

=item -profile <filespec>

Location of the optional user profile YAML file, which can be used
to define location aliases and set commonly used options such as
-cachefile.  Defaults to ~/.ghcn_fetch.yaml.

=item -h | -help

Display this documentation.

=back

=head1 AUTHOR

Gary Puckering (jgpuckering@rogers.com)

=head1 LICENSE AND COPYRIGHT

Copyright 2022, Gary Puckering

=cut
