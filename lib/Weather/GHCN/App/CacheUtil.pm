# Weather::GHCN::CacheUtil.pm - cache utility

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

Weather::GHCN::App::CacheUtil - Show or clean up cache content

=head1 SYNOPSIS

    use Weather::GHCN::App::CacheUtil;

    Weather::GHCN::App::CacheUtil->run( \@ARGV );

See ghcn_cacheutil -help for details.

=cut

########################################################################
# Pragmas
########################################################################

# these are needed because perlcritic fails to detect that Object::Pad handles these things
## no critic [ValuesAndExpressions::ProhibitVersionStrings]

use v5.18;
use warnings;

package Weather::GHCN::App::CacheUtil;

our $VERSION = 'v0.0.000';

use feature 'signatures';
no warnings 'experimental::signatures';

########################################################################
# perlcritic rules
########################################################################

## no critic [Subroutines::ProhibitSubroutinePrototypes]
## no critic [ErrorHandling::RequireCarping]
## no critic [Modules::ProhibitAutomaticExportation]

# due to use of postfix dereferencing, we have to disable these warnings
## no critic [References::ProhibitDoubleSigils]

########################################################################
# Export
########################################################################

require Exporter;

use base 'Exporter';

our @EXPORT = ( 'run' );

########################################################################
# Libraries
########################################################################
use English         qw( -no_match_vars ) ;
use Getopt::Long    qw( GetOptionsFromArray );
use Pod::Usage;
use Const::Fast;
use Hash::Wrap      {-lvalue => 1, -defined => 1, -as => '_wrap_hash'};
use Path::Tiny;
use Weather::GHCN::Common       qw(commify);
use Weather::GHCN::Station;
use Weather::GHCN::StationTable;

# modules for Windows only
use if $OSNAME eq 'MSWin32', 'Win32::Clipboard';

########################################################################
# Global delarations
########################################################################

# is it ok to use Win32::Clipboard?
our $USE_WINCLIP = $OSNAME eq 'MSWin32';

my $Opt;

########################################################################
# Constants
########################################################################

const my $EMPTY  => q();        # empty string
const my $SPACE  => q( );       # space character
const my $COMMA  => q(,);       # comma character
const my $TAB    => qq(\t);     # tab character
const my $DASH   => q(-);       # dash character
const my $TRUE   => 1;          # perl's usual TRUE
const my $FALSE  => not $TRUE;  # a dual-var consisting of '' and 0

const my $PROFILE_FILE => '~/.ghcn_fetch.yaml';


########################################################################
# Script Mainline
########################################################################

__PACKAGE__->run( \@ARGV ) unless caller;

#-----------------------------------------------------------------------
=head1 SUBROUTINES

=head2 run ( \@ARGV )

Invoke this subroutine, passing in a reference to @ARGV, in order to
manage a cache folder used by ghcn modules and scripts.

=cut

sub run ($progname, $argv_aref) {

    $Opt = get_options($argv_aref);

    my ($ghcn, $cacheobj) = get_cacheobj($Opt->profile, $Opt->cachedir);

    if ($Opt->clean) {
        my @errors = $ghcn->cache_obj->clean_cache();
        if (@errors) {
            say {*STDERR} join "\n", @errors;
            exit 1;
        }
        exit;
    }

    # send print output to the Windows clipboard if requested and doable
    outclip() if $Opt->outclip and $USE_WINCLIP;

    my $stations_href = load_cached_stations($ghcn, $cacheobj);

    return if 0 == keys $stations_href->%*;

    my $keep_href = keep_aliases($ghcn->profile_href);

    report_stations($stations_href, $keep_href);
    
    say 'Cache location: ', $cacheobj;

    # restore print output to stdout
    outclip();

    return;
}

sub outclip () {
    state $old_fh;
    state $output;

    if ($old_fh) {
        Win32::Clipboard->new()->Set( $output );
        select $old_fh;     ## no critic [ProhibitOneArgSelect]
    } else {
        open my $new_fh, '>', \$output
            or die 'Unable to open buffer for write';
        $old_fh = select $new_fh;  ## no critic (ProhibitOneArgSelect)
    }

    return;
}

sub get_cacheobj ($profile, $cachedir) {
    my $ghcn = Weather::GHCN::StationTable->new;

    $profile //= $PROFILE_FILE;

    my ($opt, @errors) = $ghcn->set_options(
        cachedir => $cachedir,
        profile => $profile,
    );
    die @errors if @errors;

    return $ghcn, path($ghcn->cachedir);
}

sub load_cached_stations ($ghcn, $cacheobj) {

    my @stns =
        map { $_->basename('.dly') }
            grep { m{ [.]dly \Z }xms }
                $cacheobj->children;

    if (not @stns) {
        say {*STDERR} "*I* no daily data in the cache";
        return;
    }

    my %filter;
    $filter{$_} = 1 for @stns;

    $ghcn->stnid_filter_href( \%filter );

    my @files = path($cacheobj)->children;

    if (not @files) {
        say {*STDERR} '*I* cache is empty';
        return {};
    }

    if (not path($cacheobj, 'ghcnd-stations.txt')->exists) {
        say {*STDERR} '*W* no ghcnd-stations.txt file in the cache';
        say {*STDERR} '*W* fallback to listing entire cache folder';
        say join "\n", @files;
        return {};
    }

    my $stations_txt = path($cacheobj, 'ghcnd-stations.txt')->slurp;

    $ghcn->load_stations( content => $stations_txt );

    my @stations = $ghcn->get_stations(list => 1, no_header => 1);
    my @hdr = Weather::GHCN::Station::Headings;

    my %stations;
    foreach my $stn_row (@stations) {
        my %stn;
        @stn{@hdr} = $stn_row->@*;
        my $pathobj = path($cacheobj, $stn{StationId} . '.dly');
        $stn{Size} = $pathobj->size;
        $stn{Age} = int -M $pathobj->stat;
        $stn{PathObj} = $pathobj;
        $stations{$stn{StationId}} = \%stn;
    }

    return \%stations;
}

sub report_stations ($stations_href, $keep_href) {

    printf "%-10s  %2s %2s %-9s %6s %4s %s\n", qw(StationId Co St Active Kb Age Location)
        unless $Opt->remove;
        
    my $total_kb = 0;
    my @removed;

    foreach my $stnid (sort keys $stations_href->%*) {
        my $stn = $stations_href->{$stnid};
        my $loc = $Opt->location;

        next if $Opt->country and $stn->{Country} ne $Opt->country;
        next if $Opt->state   and $stn->{State}   ne $Opt->state;

        my $kb = int($stn->{Size} / 1024 + 0.5);

        next if $Opt->above and $kb <= $Opt->above;
        next if $Opt->below and $kb >= $Opt->below;
        
        next if $Opt->age and $stn->{Age} < $Opt->age;

        if ($Opt->invert) {
            next if $Opt->location and $stn->{Location} =~ m{$loc}msi;
        } else {
            next if $Opt->location and $stn->{Location} !~ m{$loc}msi;
        }

        $total_kb += $kb;

        if ( $Opt->remove and not $keep_href->{$stnid} ) {
            push @removed, $stnid . ' ' . $stn->{Location};
            $stn->{PathObj}->remove;
            next;
        }
        
        printf "%10s %2s %2s %9s %6s %4s %s\n",
            $stn->{StationId},
            $stn->{Country},
            $stn->{State},
            $stn->{Active},
            sprintf('%6s', commify( $kb )),
            $stn->{Age},
            $stn->{Location},
            ;
    }

    if (@removed) {
        say 'Daily data removed:';
        foreach my $s (@removed) {
            say $s;
        }
    } else {       
        say '';
        say "Total cache size: ", commify($total_kb);
    }

    return;
}

sub keep_aliases ($profile_href) {
    return {} if not $profile_href;
    my $aliases_href = $profile_href->{aliases};
    return {} if not $aliases_href;
    my %keep;
    foreach my $stn_str (values $aliases_href->%*) {
        my @stns = split $COMMA, $stn_str;
        foreach my $stn (@stns) {
            $keep{$stn} = 1;
        }
    }
    return \%keep;
}

########################################################################
# Script-standard Subroutines
########################################################################

=head2 get_options ( \@ARGV )

B<get_options> encapsulates everything we need to process command line
options, or to set options when invoking this script from a test script.

Normally it's called by passing a reference to @ARGV; from a test script
you'd set up a local array variable to specify the options.

By convention, you should set up a file-scoped lexical variable named
$Opt and set it in the mainline using the return value from this function.
Then all options can be accessed used $Opt->option notation.

=cut

sub get_options ($argv_aref) {

    my @options = (
        'country:s',            # filter by country
        'state|prov:s',         # filter by state or province
        'location:s',           # filter by localtime
        'remove',               # remove cached daily files (except aliases)
        'clean',                # remove all files from the cache
        'invert|v',             # invert -location selection criteria
        'above:i',              # select files with size > than this
        'below:i',              # select file with size < this
        'age:i',                # select file if >= age
        'cachedir:s',           # cache location
        'profile:s',            # profile file
        'outclip',              # output data to the Windows clipboard
        'help','usage|?',       # help
    );

    my %opt;

    # create a list of option key names by stripping the various adornments
    my @keys = map { (split m{ [!+=:|] }xms)[0] } grep { !ref  } @options;
    # initialize all possible options to undef
    @opt{ @keys } = ( undef ) x @keys;

    GetOptionsFromArray($argv_aref, \%opt, @options)
        or pod2usage(2);

    # Make %opt into an object and name it the same as what we usually
    # call the global options object.  Note that this doesn't set the
    # global -- the script will have to do that using the return value
    # from this function.  But, what this does is allow us to call
    # $Opt->help and other option within this function using the same
    # syntax as what we use in the script.  This is handy if you need
    # to rename option '-foo' to '-bar' because you can do a find/replace
    # on '$Opt->foo' and you'll get any instances of it here as well as
    # in the script.

    ## no critic [Capitalization]
    ## no critic [ProhibitReusedNames]
    my $Opt = _wrap_hash \%opt;

    pod2usage(1)             if $Opt->usage;
    pod2usage(-verbose => 2) if $Opt->help;

    return $Opt;
}

1;