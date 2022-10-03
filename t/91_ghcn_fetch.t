use strict;
use warnings;
use v5.18;      # minimum needed for Object::Pad

use FindBin;
use lib $FindBin::Bin . '/../lib';

use Test::More tests => 11;

use Capture::Tiny             qw( capture );
use Const::Fast;
use Module::Load::Conditional qw(check_install);
use Path::Tiny;

use Weather::GHCN::App::Fetch;

my $Bin = $FindBin::Bin;

const my $TRUE   => 1;          # perl's usual TRUE
const my $FALSE  => not $TRUE;  # a dual-var consisting of '' and 0
const my $PROFILE => path($Bin)->child('ghcn_fetch.yaml');

my $Cachedir = path($Bin,'ghcn_cache');

if (not -d $Cachedir) {
    BAIL_OUT "*E* cached folder is missing";
}

my $Refresh;       # control caching

my @cachefiles = path($Cachedir)->children;
if (@cachefiles > 0) {
    # do not contact the server
    $Refresh = 'never';
    ok $TRUE, "using cached files: $Cachedir\n";
} else {
    # The cache is empty, enable refreshing the cache.
    # Note that it may take some time to fetch the pages.
    # Expect the cache to be about 45 Mb
    $Refresh = 'always';
    ok $TRUE, "creating cache: $Cachedir\n";
}

BAIL_OUT if not -r $PROFILE;

my @args = (
        '-country',     'US',
        '-state',       'NY',
        '-location',    'New York',
        '-active',      '1900-1910',
        '-report',      '',
        '-refresh',     'never',
        '-profile',     $PROFILE,
        '-cachedir',    $Cachedir,
);

my ($stdout, $stderr) = capture {
    Weather::GHCN::App::Fetch->run( \@args );
};

my @result = split "\n", $stdout;

my $hdr;
my $matches;
foreach my $r (@result) {
    next unless $r;
    $hdr++      if $r =~ m{ \A StationId \t Country }xms;
    $matches++  if $r =~ m{ NEW \s YORK }xms;
    last if $r =~ m{ \A Options: }xms;
}

is $hdr, 1, 'Weather::GHCN::App::Fetch returned a header';
is $matches, 11, 'Weather::GHCN::App::Fetch returned 9 entries for NEW YORK';

# for test coverage

is Weather::GHCN::App::Fetch::deabbrev_report_type('da'), 'daily', 'deabbrev_report_type';
is Weather::GHCN::App::Fetch::deabbrev_refresh_option('y'), 'yearly', 'deabbrev_refresh_option';

local @ARGV = qw(-report detail);

my $opt_href = Weather::GHCN::App::Fetch::get_user_options_no_tk;
is $opt_href->{'report'}, 'detail', 'get_user_options_no_tk';

@ARGV = qw(-report detail);

if ( check_install(module=>'Tk') and check_install(module=>'Tk::Getopt')) {
    $opt_href = Weather::GHCN::App::Fetch::get_user_options_tk;
    is $opt_href->{'report'}, 'detail', 'get_user_options_tk';
} else {
    ok 1, 'Tk or Tk::Getopt not installed';
}

my @opttable = ( Weather::GHCN::Options->get_tk_options_table() );

@opttable = ( Weather::GHCN::Options->get_tk_options_table() );
ok  Weather::GHCN::App::Fetch::valid_report_type('detail',\@opttable),  'valid_report_type - detail valid';
ok !Weather::GHCN::App::Fetch::valid_report_type('xxx',\@opttable),     'valid_report_type - xxx invalid';

ok  Weather::GHCN::App::Fetch::valid_refresh_option('never',\@opttable),'valid_refresh_option - never valid';
ok !Weather::GHCN::App::Fetch::valid_refresh_option('xxx',\@opttable),  'valid_refresh_option - xxx invalid';
