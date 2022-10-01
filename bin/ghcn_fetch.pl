# ghcn_fetch.pl - Fetch NOAA GHCN daily data and output as TSV

# Testing notes:
#
# The quickest way to spot check results from this script is to compare them
# to those obtained from:
#
#   https://ottawa.weatherstats.ca/charts/
#
# Run the script with parameters such as -prov ON -loc "Ottawa Int" -range
# 2017-2018 -precip -tavg -o first with the -daily option, then again with
# -monthly and -yearly. You can then compare results to various charts you
# generate using the above link by selecting Ottawa (Kanata - Orleans),
# which I've verified corresponds to station CA006105976 (Ottawa Int'l).
#
# Charts to use include Temperature (TMAX, TMIN, TAVG, Avg), Snowfall
# (SNOW), Snow on Ground (SNWD) and Total Precipitation (PRCP). Annual and
# monthly charts work well, but you may need daily charts and some
# investigation of the NOAA source data if there are anomalies. Sometimes
# the NOAA data has missing data; e.g. station CA006105976 (Ottawa Int'l)
# is missing days 6-28 for 2018-02.

########################################################################
# Pragmas
########################################################################
use v5.18;  # minimum for Object::Pad

our $VERSION = 'v0.0.000';

use Weather::GHCN::App::Fetch;

Weather::GHCN::App::Fetch->run( \@ARGV );

########################################################################
# Documentation
########################################################################
__END__

=head1 NAME

ghcn_fetch.pl - Fetch station and weather data from the NOAA GHCN repository

=head1 SYNOPSIS

    ghcn_fetch.pl [-gui] [-optfile <filespec>]

    ghcn_fetch.pl [<report_type>]
            [-country <str>] [-state <str>] [-location <str>] [-gsn]
            [-gps "<lat> <long>" [-radius <n>] ]
            [-range <str>] [-active <str> [-partial]] [-quality <pct>]
            [-fmonth <str>] [-fday <str>]
            [-anomalies] [-baseline <str>] [-precip] [-tavg] [-nogaps]
            [-kml <filespec> [-color <str>] ]
            [-dataonly] [-refresh <str>] [-performance] [-verbose]
            [-outclip]
            [-report <report_type>]

        <report_type> ::= id | daily | monthly | weekly | ""

    ghcn_fetch.pl -readme

    ghcn_fetch.pl -help

    ghcn_fetch.pl -usage | -?

=head1 DESCRIPTION

Fetch data from the NOAA GHCN database and output as tab-separated lines.
Various options are provided to allow filtering of the NOAA stations
by country, state, location name, year range, station active year
range, etc.  When no report type is provided, or -report is an empty
string, the output is simply a list of the selected stations.

If report type 'daily', 'monthly' or 'yearly' is given, then the
pages for the selected stations are scanned and the data from them
aggregated and output as one row per designated period.  This is
followed by the station list.

If report type 'detail' is given, then the daily data for each selected
station id is reported, followed by the station list.

The report type can be abbreviated; e.g. d or da for daily.  The report
type can be provided as the first argument, or it can be provided via
the -report option anywhere within the argument list.

In general it's best to narrow your filter criteria as much as
possible otherwise it will take a very long time to load and process
the station pages. A good strategy is to omit the -report option so
you can see how many stations will be queried before asking for any
detailed data.  Then you can adjust the number of stations using
other filters.

If no options are given, and stdin isn't receiving from a pipe or a
file, then -gui is assumed.  This launches a dialog to provide a
user-friendly way to set options, and to save and reload them (if
-optfile is provided).

=head1 PARAMETERS

Getoptions::Long is used, so either - or -- may be used.  Parameter
names may be abbreviated, so long as they remains unambiguous.


=head2 Report Types


Data obtained from the GHCN database can be reported at various
levels of aggregation using the -report option.  The string value
given to -report specifies the type and level of aggregation.
Abbrevations are permitted.

=over 4

=item -report "" (or omitted)

This is the default option when no report option is provided, or when
the option is an empty string.  It generates a list of the stations 
which match the criteria provided (location, geo coordinates, ranges 
etc.)  No actual weather data is accessed; only station data.

=item -report daily

Scan the NOAA station pages that meet all the selection criteria and
aggregate the data from them by year, month and day.  Output the
results as a tab-separated table suitable for import into Excel for
analysis.

TMAX (temperature maximum) is aggregated by maximum; TMIN by
minimum; TAVG values are averaged.  Note that while most stations
track TMAX and TMIN, a lot fewer track TAVG.  When TAVG is missing,
a proxy is calculated by averaging TMAX and TMIN.

=item -report monthly

Same as -daily except the output is summarized to the month level.
Note that with this option, TAVG is average across days of the month
and may of limited usefulness. Avg will be calculated as the average
of the max and min for the month, which is what is typically used as
the measure for monthly average temperature.

=item -report yearly

Same as -daily except the output is summarized to the year level.
See the explanation of TAVG vs Avg on -monthly.

=item -report detail

Break the selected aggregation level down by station id and include
the station id in the output.  This is like -daily, but with a
separate set of rows for each station id.

=back

=head2 Station Filter

A list of station id's can be provided via stdin, and will be used in
lieu of other filtering criteria.  Each line of input will be searched
for one or more station id's.

=head2 Geographic Filters

=over 4

=item -country <str>

Filter the station list to include only those from a specific
country.  The string can be a 2-character GEC (formerly FIPS)
country code, a 3-character UN country code, or a 3-character
internet country code (including the dot).  Longer strings are
treated as a pattern and matched (unanchored) against country names.

NOAA uses GEC codes in their database.  For a full list of country
codes and names see
L<https://www1.ncdc.noaa.gov/pub/data/ghcn/daily/ghcnd-countries.txt>
and
L<https://www.cia.gov/library/publications/the-world-factbook/appendix/appendix-d.html>


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

=item -gsn

Select only GCOS Surface Network stations, which  is a baseline
network comprising a subset of about 1000 stations chosen mainly to
give a fairly uniform spatial coverage from places where there is a
good length and quality of data record.  See
L<https://www.ncdc.noaa.gov/gosic/global-climate-observing-system-gcos/g
cos-surface-network-gsn-program-overview>

=item -gps <latitude>,<longitude>

Filter the station list to include only those stations that are
within -radius kilometers (default 25) of the specified decimal
latitude and longitude values; e.g. 45.3822 -75.7167. The two value
can be delimited by spaces, or any punctuation character (e.g.
comma).  If a space is used, the string must be enclosed in quotes.

=item -radius <int>

Specify the radius, in kilometers, to be used for the -gps option.

=item Date Filters

=item -range <str>

Only include data from the specified range of years.  The range is
given as a string such as 1990-2018.  Any punctuation character can
be used to separate the two years.  A single year may also be
given.  Alternatively, two discontiguous years can be given by
separating the years with a comma (e.g. -range 1919,2019), although
this feature cannot be combined with -active and with -anomalies.

Note that if -active is specified, then -range must be a subset of
-active since there's no point in asking for data that lies outside
the active range of data collection for a station.

=item -active <str>

Only include data from stations which have been fully active within
the specified range.  The range is given as a string such as
1990-2018.  Any punctuation character can be used to separate the
two years.    A single year may also be given.

Instead of a year range, you can use an empty string to set the
active range to match the range specified by -range.

=item -partial

The -partial option can be used in conjunction with -active to
include stations that were only active during part of the active
range.

=item -quality <int>

Only include stations which have <int>% days of unflagged data
within -range.  If -anomalies is given, the number of days within
the -baseline range is also checked against <int>%.  The default
value for -quality is 90, meaning that 90% of the days found within
-range (and -baseline) must be present and unflagged in order for
the station's data to be included in the output.

=item -fday <str>

Filter the data so that it includes only the days of the month which
match the specified range list; e.g. 5-10,20.

=item -fmonth <str>

Filter the data so that it includes only the months of the year
which match the specified range list; e.g. 1-3,7-9 would select
Jan-Mar and Jul-Sep.

=back

=head2 Analysis Options

=over 4

=item -anomalies

Calculate the mean temperature anomalies for each day at each
station relative to a baseline year range (see -baseline).  Include
these in the output.

=item -baseline <str>

Use the date range <str> to compute anomalies.  Default 1971-2000.

=item -precip

Include precipitation measures in the output, specifically SNOW,
SNWD (snow depth), ans PRCP (all precipitation). Values are in cm.
Like TMAX, SNWD is the maximum depth recorded across stations and
across time.  The others are averaged across stations and then
summed across time.  In other words, if -year is used you get the
maximum snow depth for the year, and the total accumulation of snow
and precipitfor the year.

=item -tavg

Include TAVG (average daily temperature) in the output.  TAVG will
be averaged across stations and also across months or years if
-monthly or -yearly is given.

=item -nogaps

For report 'detail', generate rows for those months and days where data
is missing.  This enables charting with a complete time x-axis.
Without it, large gaps result in horizontal compression of the
chart and a distorted picture across time.

=back

=head2 Kml Options

=over 4

=item -kml <filespec>

Output the coordinates of the selected stations as a KML file, for
import into Google Earth as placemarks.  The active range of each
station will be included as timespans so that you can view the
placemarks across time.

=item -color <color> (or -colour)

Color of the KLM placemark pushpins.  Acceptable values are red,
green, blue, azure, purple, yellow and white.  May be abbreviated
down to one letter. Default is red.

=back

=head2 Output Options

=over 4

=item -outclip or -o

Send output to the Windows clipboard.  (Windows only)

=back

=head2 Misc Options

=over 4

=item -dataonly

Print only the data table.  Other information, including notes, lists
of stations kept and rejected, and statistics are suppressed.

=item -refresh <str>

This option determines whether and when cached files are refreshed from
the network source.  Default is yearly.  Possible values are:

=over 4

=item yearly

The origin HTTP server is contacted and the page refreshed if the
cached file has not been changed within the current year. The
rationale for this, and for this being the default, is that the GHCN
data for the current year will always be incomplete, and that will
skew any statistical analysis and so should normally be truncated.
If the user needs the data for the current year, they should use a
refresh value of 'always' or a number.

=item always

If a page is in the cache, the origin HTTP server is always checked for
a fresher copy

=item never

The origin HTTP is never contacted, regardless of the page being in
cache or not. If the page is missing from cache, the fetch method will
return undef. If the page is in cache, that page will be returned, no
matter how old it is.

=item <number>

The origin HTTP server is not contacted if the page is in cache
and the cached page was inserted within the last <number> days.
Otherwise the server is checked for a fresher page.

=back

=item -performance

Include performance statistics in the output.  This includes some
extra timing information (labelled "(internal)" in the Time
Statistics list because they are internal to the other timing
metrics) as well as statistics for the memory consumption of the
Data hash table.  Also some memory statistics are added to some
Timing subjects.

=item -verbose

When given, warning messages about missing data are displayed to
stderr.

=back

=head2 Command-Line Only Options

=over 4

=item -gui

Launch a graphic user interface that can be used to set options.
Not available unless modules Tk and Tk::Getopt are installed.

=item -optfile <filespec>

Designate a file to be used to save or load options.

=item -readme

Launch the default web browser and display the NOAA Daily Readme.txt
file, providing a description of the Daily data files and station
data.

=item -h | -help

Display this documentation.

=item -usage | -?

Display the Synopsis section of this documentation.

=back

=head1 CONFIGURATION FILE

At startup, ghcn_fetch will look for the file .ghcn_fetch.yaml in
either %UserProfile% (Windows) or $HOME (unix/linux) in order to capture some
additional options. The file content should contain something like this:

    ---
    cache:
        root: C:/ghcn_cache

    aliases:
        yow: CA006106000,CA006106001    # Ottawa airport
        cda: CA006105976,CA006105978    # Ottawa CDA and CDA RCS
        center: USC00326365             # geographic center of North America

Supported options are:

=over 4

=item cache:

This section defines the cache_root options for GHCN::CacheURI.
If present, then any pages which are fetched from the NOAA GHCN repository
are cached in the folder designated by root.
This vastly improves the performance of subsequent invocations of
ghcn_fetch, especially when using the same station filtering criteria.

=item aliases:

This section provides a list of shortcut names that are mapped to
station id's or id-lists and which can be used in the -location
option.  If a -location value matches a key in this section, the
station id or id-list is substituted.  Note that keys must be lowercase
letter only, with or without a leading underscore.

=back

=head1 RELATED SCRIPTS

Additional scripts are provided for data analysis.  These scripts
are designed to take the output ghcn_fetch.

For Windows users, a -outclip option directs the tab-separated output
to the Windows clipboard, so it can be pasted into Excel for analysis
using PivotTable and PivotChart. Alternatively you can use the usual
'>' method to direct the output to a file.

=over 4

=item ghcn_extremes.pl

Report patterns of temperature extremes (heatwaves or coldwaves) by
analyzing daily temperature records and looking for consecutive days
of extreme temperatures; e.g.

    ghcn_fetch -country CA -report daily | ghcn_extremes > extremes.tsv

=item ghcn_station_counts.pl

Report the station counts per year for a list of stations generated by
this script using -report stations (which is the default -report
option); e.g.

    ghcn_fetch -country CA | ghcn_station_counts > stn_counts.tsv

=back

=head1 AUTHOR

Gary Puckering (jgpuckering@rogers.com)

=head1 LICENSE AND COPYRIGHT

Copyright 2022, Gary Puckering

=cut
