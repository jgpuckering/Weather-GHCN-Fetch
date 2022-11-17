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

    my @files = $argv_aref->@*;

    my ( $output, $new_fh, $old_fh );
    if ( $Opt->outclip and $USE_WINCLIP ) {
        open $new_fh, '>', \$output
            or die 'Unable to open buffer for write';
        $old_fh = select $new_fh;  ## no critic (ProhibitOneArgSelect)
    }

    my ($ghcn, $stations_href) = load_cached_stations($Opt->profile, $Opt->cachedir);

    my $keep_href = keep_aliases($ghcn->profile_href);

    report_stations($stations_href, $keep_href);
    
WRAP_UP:
    # send output to the Windows clipboard
    if ( $Opt->outclip and $USE_WINCLIP ) {
        Win32::Clipboard->new()->Set( $output );
        select $old_fh;     ## no critic [ProhibitOneArgSelect]
    }

    
}

sub load_cached_stations ($profile, $cachedir) {
#    my $cachedir //= path('c:/ghcn_cache');
    my $ghcn = Weather::GHCN::StationTable->new;

    $profile //= $PROFILE_FILE;

    my ($opt, @errors) = $ghcn->set_options(
        cachedir => $cachedir,
        profile => $profile,
    );
    die @errors if @errors;

    my $cache_obj = path($ghcn->cachedir);
    
    my @stns =
        map { $_->basename('.dly') }
            grep { m{ [.]dly \Z }xms }
                $cache_obj->children;
                               
    my %filter;
    $filter{$_} = 1 for @stns;

    $ghcn->stnid_filter_href( \%filter );

    my $stations_txt = path($cache_obj, 'ghcnd-stations.txt')->slurp;

    $ghcn->load_stations( content => $stations_txt );

    my @stations = $ghcn->get_stations(list => 1, no_header => 1);
    my @hdr = Weather::GHCN::Station::Headings;

    my %stations;
    foreach my $stn_row (@stations) {
        my %stn;
        @stn{@hdr} = $stn_row->@*;
        my $pathobj = path($cache_obj, $stn{StationId} . '.dly');
        $stn{Size} = $pathobj->size;
        $stn{PathObj} = $pathobj;
        $stations{$stn{StationId}} = \%stn;
    }

    return $ghcn, \%stations;
}

sub report_stations ($stations_href, $keep_href) {

    say join "\t", qw(StationId Country State Active Bytes Removed Location);
    my $total_size = 0;

    foreach my $stnid (sort keys $stations_href->%*) {
        my $stn = $stations_href->{$stnid};
        my $loc = $Opt->location;
        next if $Opt->country  and $stn->{Country}  ne $Opt->country;
        next if $Opt->state    and $stn->{State}    ne $Opt->state;
        next if $Opt->location and $stn->{Location} !~ m{ $loc }xmsi;
        $total_size += $stn->{Size};
        my $size = sprintf '%10s', commify( $stn->{Size} );
        
        my $removed = $EMPTY;
        if ( $Opt->remove and not $keep_href->{$stnid} ) {
            $stn->{PathObj}->remove;
            $removed = 'removed',
        }

        say join "\t",
            $stn->{StationId},
            $stn->{Country},
            $stn->{State},
            $stn->{Active},
            $size,
            $removed,
            $stn->{Location},
            ;
    }
    say '';
    say "Total cache size: \t\t\t\t", commify($total_size);

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