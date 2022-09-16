#!/usr/bin/perl
# ghcn_station_counts.pl - Count stations in ghcn_fetch.pl station output

########################################################################
# Pragmas
########################################################################
use v5.18;  # minimum for Object::Pad

our $VERSION = 'v0.0.000';

use Weather::GHCN::App::StationCounts;

Weather::GHCN::App::StationCounts->run( \@ARGV );

########################################################################
# Documentation
########################################################################
__END__

=head1 NAME

ghcn_station_counts.pl - Count stations in ghcn_fetch.pl output

=head1 SYNOPSIS

    ghcn_station_counts.pl [-input] [-output] [-debug] [-verbose] [ file... ]

    ghcn_station_counts.pl [--help | -? | --usage]

=head1 DESCRIPTION

The purpose of this script is to read a station list produced by
"ghcn_fetch.pl" and to turn that list into a set of active
station counts for each year.  No report option should be given,
so it generates a list of stations rather than weather data.

The input data must be tab-separated and contain the Station ID, the
country, the state/province, and the active range (e.g. 1900-1927).
All trailing columns of data are ignored.

In typical use, you would extract the stations of interest with:

    ghcn_fetch -report "" <other_options>

and then either pipe it to ghcn_station_counts or save the output to a
file and then use that file as input to ghcn_station_counts.

The output is a tab-separated three-column list consisting of the year,
decade, and the count of active stations found in that year.
This is suitable for importing into Excel and turning into a bar chart
using PivotTable.  You can chart by year or decade, using the average,
maximum or minimum of the station count.

=head1 PARAMETERS

Getoptions::Long is used, so either - or -- may be used.  Parameter
names may be abbreviated, so long as they remains unambiguous.  Flag
options may appear after filenames.

=over 4


=item -outclip

Send output to the Windows clipboard.

=item -debug

Enables debug() statements.

=item -h | -help

Display this documentation.

=back

=head1 AUTHOR

Gary Puckering (jgpuckering@rogers.com)

=head1 LICENSE AND COPYRIGHT

Copyright 2022, Gary Puckering

=cut
