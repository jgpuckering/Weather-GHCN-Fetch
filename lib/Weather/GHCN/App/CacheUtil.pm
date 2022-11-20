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

sub run ($progname, $argv_aref) {

    $Opt = get_options($argv_aref);

    my ($ghcn, $cacheobj) = get_cacheobj($Opt->profile, $Opt->cachedir);

    if ($Opt->clean) {
        my @errors = $ghcn->cache_obj->clean_cache();
        if (@errors) {
            say {*STDERR} join "\n", @errors;
            exit 1;
        }
        return;
    }

    # send print output to the Windows clipboard if requested and doable
    outclip() if $Opt->outclip and $USE_WINCLIP;

    my $keep_href = keep_aliases($ghcn->profile_href);

    my $files_href = load_cached_files($ghcn, $cacheobj, $keep_href);
    
    if ($Opt->remove) {
        foreach my $fileid (sort keys $files_href->%*) {
            my $file = $files_href->{$fileid};
            next unless $file->{INCLUDE};
            say {*STDERR} 'Removing ', $file->{PathObj};
            $file->{PathObj}->remove;
        }
        return;
    }

    my $total_kb = report_daily_files($files_href);

    say '';
    say "Total cache size: ", commify($total_kb);
    say 'Cache location: ', $cacheobj;

    # restore print output to stdout
    outclip();

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
        'type:s',               # select based on type
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


sub load_cached_files ($ghcn, $cacheobj, $keep_href) {

    my @files = $cacheobj->children;

    if (not @files) {
        say {*STDERR} '*I* cache is empty';
        return {};
    }

    my @txtfiles;
    my %filter;
    foreach my $po (@files) {
        my $bname = $po->basename;
        if ( $bname =~ m{ [.]txt \Z}xms ) {
            push @txtfiles, $po;
            next;
        }
        my $stnid = $po->basename('.dly'); # removes the extension
        $filter{$stnid} = 1;
    }


    if (@txtfiles == 0) {
        say {*STDERR} '*W* no station catalog files (ghcnd-*.txt) in the cache - resorting to a simple file list';
        say $_->basename for @files;
        return {};
    }

    my $stations_txt = path($cacheobj, 'ghcnd-stations.txt')->slurp;

    $ghcn->stnid_filter_href( \%filter );
    $ghcn->load_stations( content => $stations_txt );

    my @stations = $ghcn->get_stations(list => 1, no_header => 1);
    my @hdr = Weather::GHCN::Station::Headings;

    my %files;
    foreach my $stn_row (@stations) {
        my %file;
        @file{@hdr} = $stn_row->@*;

        my $fileid = $file{StationId};
        my $pathobj = path($cacheobj, $fileid . '.dly');

        $file{Type} = $keep_href->{$fileid} ? 'A' : 'D';
        $file{Size} = $pathobj->size;
        $file{Age} = int -M $pathobj->stat;
        $file{PathObj} = $pathobj;
        $files{$file{StationId}} = \%file;
    }

    foreach my $po (@txtfiles) {
        my %file;
        my $fileid = $po->basename('.txt');
        $fileid =~ s{ \A ghcnd- }{}xms;
        $file{StationId} = $fileid;
        $file{Location} = $po->basename;
        $file{Type} = 'C';
        $file{Size} = $po->size;
        $file{Age} = int -M $po->stat;
        $file{PathObj} = $po;
        $files{$file{StationId}} = \%file;
    }

    filter_files(\%files);
    
    return \%files;
}


sub match_type ($t) {
    return $TRUE if not $Opt->type;
    my @types = split //, $Opt->type;
    my $matched = 0;
    foreach my $u (@types) {
        $matched++ if uc $u eq uc $t
    }
    return $matched++
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

sub filter_files ($files_href) {
    foreach my $fileid (sort keys $files_href->%*) {
        my $file = $files_href->{$fileid};
        my $loc = $Opt->location;

        next unless match_type( $file->{Type} );

        next if $Opt->country and $file->{Country} ne $Opt->country;
        next if $Opt->state   and $file->{State}   ne $Opt->state;

        my $kb = round($file->{Size} / 1024);

        next if $Opt->above and $kb <= $Opt->above;
        next if $Opt->below and $kb >= $Opt->below;

        next if $Opt->age and $file->{Age} < $Opt->age;

        if ($Opt->invert) {
            next if $Opt->location and $file->{Location} =~ m{$loc}msi;
        } else {
            next if $Opt->location and $file->{Location} !~ m{$loc}msi;
        }
        
        $file->{INCLUDE} = 1;
    }
}

sub report_daily_files ($files_href) {

    printf "%s %-11s %2s %2s %-9s %6s %4s %s\n", qw(T StationId Co St Active Kb Age Location);
    
    my $total_kb = 0;

    foreach my $fileid (sort keys $files_href->%*) {
        my $file = $files_href->{$fileid};
        next unless $file->{INCLUDE};

        my $kb = round($file->{Size} / 1024);
        $total_kb += $kb;
       
        no warnings 'uninitialized';
        printf "%s %-11s %2s %2s %9s %6s %4s %s\n",
            $file->{Type},
            $file->{StationId},
            $file->{Country},
            $file->{State},
            $file->{Active},
            sprintf('%6s', commify( $kb )),
            $file->{Age},
            $file->{Location},
            ;
    }

    return $total_kb;
}


sub report_catalog_files ($txtfiles_href) {
    my $total_kb = 0;
    foreach my $k (sort keys $txtfiles_href->%*) {
        my $kb = $txtfiles_href->{$k};
        $total_kb += $kb;
        printf "%s %-27s %6s\n", 'C' ,$k, commify($kb);
    }
    return $total_kb;
}


sub round ($n) {
    return int($n + .5);
}

1;