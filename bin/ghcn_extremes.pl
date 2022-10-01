#!/usr/bin/perl
# ghcn_extremes.pl - Report temperature extremes from ghcn_fetch.pl output

use v5.18;  # minimum for Object::Pad

our $VERSION = 'v0.0.000';

use Weather::GHCN::App::Extremes;

Weather::GHCN::App::Extremes->run( \@ARGV );

########################################################################
# Documentation
########################################################################
__END__

=head1 NAME

ghcn_extremes.pl - Report temperature extremes from ghcn_fetch.pl output

=head1 SYNOPSIS

    ghcn_extremes.pl [-limit <int>] [-ndays <int>]
                     [-peryear] [-daycounts] [-cold] [-nogaps]
                     [-outclip] [ file... ]

    ghcn_extremes.pl [--help | -? | --usage]

=head1 DESCRIPTION

Report patterns of temperature extremes (heatwaves or coldwaves) by
analyzing daily temperature records and looking for consecutive days
of extreme temperatures.  By default the script reports a count of
heatwaves in each year of the input data, where a heatwave is defined
as 5 or more consecutive days where the maximum temperature is 30
Celsius or higher.

Using the -cold option, it can report coldwaves; by default, where
the temperatures are at or below -20 C for 5 days or more days.

When the -daycounts option is given, the script reports the
year-month-day the heatwave (or coldwave) began along with a count of
the number of consecutive days it lasted.

The input data must be tab-separated, in date order, and contain the
following fields:

    year, month, day, decade,     # decade is 10 * int( year % 100 / 10 )
    s_decade, s_year, s_qtr,      # seasonal period (Jul-Jun years)
    tmax, tmin, tavg, qflags,     # qflags are ignored, so may be empty
    stn_id, station_name

All trailing columns of data are ignored.  This format is the one
generated by ghcn_fetch -report detail; i.e. it is a report
of daily weather data for each station id.

In typical use, you would extract the data of interest with

    ghcn_fetch -report detail <other_options>

and then either pipe it to ghcn_extremes or save the output to a file
and then use that file as input to ghcn_extremes.


=head1 PARAMETERS

Getoptions::Long is used, so either - or -- may be used.  Parameter
names may be abbreviated, so long as they remains unambiguous.  Flag
options may appear after filenames.

=over 4

=item -limit <int>

Sets the limit (in degrees Celsius) at or above which the TMAX temperature
for the day is counted as part of a heatwave.  Defaults to 30 Celsius.

When -cold is given, the limit is the temperature at or below which the
TMIN temperature for the day is counted as part of a coldwave.  Defaults
to -20 Celsius.

=item -ndays <int>

Consider any consecutive run of <int> or more days where the temperature
exceeds that specified by -limit as a heatwave (or coldwave).

=item peryear

Report number of heatwaves per year.

=item -daycounts

Report the number of days in each heatwave (or coldwave, rather than
the number of heatwaves (or coldwaves) per year.

=item -cold

Report coldwaves instead of heatwaves.  Days with temperatures less
than or equal to the value specified by -limit will be counted.  The
default for -limit is set to -20 Celsius when this option is selected.

=item -nogaps

When a year has no heat (or cold) waves, there will be no data for
that year in the output.  Thus, when charting, those years are missing
from the x-axis, which not only distorts the picture, it can lead
to inaccurate trend analysis.

When -nogaps is specified, the script will fill in these gaps by
adding rows at the end with the missing years.  It will be necessary
to manually sort the table in Excel, or specify an ascending sort
order for the year axis, in order for charts to look correct.

=item -outclip

Send output to the Windows clipboard.

=item -h | -help

Display this documentation.

=back

=head1 INPUT

The input data is expected to be tab-separated, with columns year,
month, day, then four other columns, then TMAX and TMIN columns.  TMAX
values are used for determining heatwaves.  TMIN values are used for
coldwaves.

The first row of data can be a row header, but column 1 must have
the value 'Year' and columns 6 and 7 must begin with 'TMAX' and 'TMIN'
respectively.

=head1 RELATED SCRIPTS

This script was designed to use the output from noaa_daily_parser.pl,
specifically when the option "-report daily" is used.  It generates
the correct level and format of data for input to this script.

The option "-report detail" can also be used, but if the data contains
multiple stations then this script will miscount.

=head1 AUTHOR

Gary Puckering (jgpuckering@rogers.com)

=head1 LICENSE AND COPYRIGHT

Copyright 2022, Gary Puckering

=cut
