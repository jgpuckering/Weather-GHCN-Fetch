# Weather::GHCN::CacheURI.pm - class for fetching from a URI, with file caching

## no critic (Documentation::RequirePodAtEnd)
=head1 NAME

Weather::GHCN::CacheFile - File-based cache using one folder for all cache files

=head1 SYNOPSIS

    use Weather::GHCN::CacheFile;

    my $cache = Weather::GHCN::CacheFile->new($root_dir);

    my ($from_cache, $content) = $cache->fetch($uri);

    my $content = $cache->load($uri);

    $cache->store($uri, $content);

=head1 DESCRIPTION

This cache module enables callers to fetch web pages and store the
content on the filesystem so that it can be retrieved subsequently
without a network access.

Unlike caching performed by Fetch::URI or LWP, no Etags or
Last-Modified-Data or other data is included with the content data.
This metadata can be an obstacle to platform portability.
Essentially, it's raw content that is stored.  If the content is
platform neutral, then the cache file can be used on any platform.
This is a benefit to unit testing, because tests can be constructed
to fetch pages, and the cached pages can be packaged with the tests.
This allows the tests to run faster, and without network access.

The approach is simple, and geared towards accessing and caching
the content of the NOAA GHCN weather repository.  The files in that
repository are simple ASCII files with uncomplicated names.  The
caching algorithm simply strips off the URI path and stores the file
using the filename found in the repository; e.g. 'ghcnd-stations.txt' or
'CA006105887.dly'.  All files are kept in the root directory, since
all filenames are expected to be unique.

=cut

use v5.18;  # minimum for Object::Pad
use Object::Pad 0.66 qw( :experimental(init_expr) );

package Weather::GHCN::CacheURI;
class   Weather::GHCN::CacheURI;

our $VERSION = 'v0.0.000';

use Carp                    qw(carp croak);
use Const::Fast;
use Fcntl qw( :DEFAULT );
use File::stat;
use Path::Tiny;
use Time::Piece;
use LWP::Simple;

const my $TRUE    => 1;          # perl's usual TRUE
const my $FALSE   => not $TRUE;  # a dual-var consisting of '' and 0
const my $EMPTY   => q();
const my $ONE_DAY => 24*60*60;   # number of seconds in a day

# First return value from _fetch methods indicating whether the fetch
# was from the cache or the web page URI
const my $FROM_CACHE => $TRUE;
const my $FROM_URI   => $FALSE;

field $_root_dir          :reader;

=head1 METHODS

=head2 new ($root_dir)

New instances of this class must be provided a location for the cache
files upon creation ($root_dir).  This directory will be created as
needed on the first cache store.

=cut

BUILD ($cache_root) {
    $_root_dir = $cache_root;
}

=head2 clean_cache

Removes all the files in the cache, but leaves the cache directory.
Returns a reference to an array of errors, which will be empty if
there were no errors.

=cut

method clean_cache () {
    my $error_aref;
    path($_root_dir)->remove_tree(
        {
            keep_root   => $TRUE,
            error       => \$error_aref,
        }
    );
    return $error_aref;
}

=head2 fetch ($uri, $refresh="yearly")

Fetch the web page given by the URI $uri, returning its content
and caching it.

=over 4

=item $uri

A URI to the location of the web page to be fetched, or retrieved
from the cache.

=item refresh 'yearly'

The origin HTTP server is contacted and the page refreshed if the
cached file has not been changed within the current year. The
rationale for this, and for this being the default, is that the GHCN
data for the current year will always be incomplete, and that will
skew any statistical analysis and so should normally be truncated.
If the user needs the data for the current year, they should use a
refresh value of 'always' or a number.

=item refresh 'never'

The origin HTTP is never contacted, regardless of the page being in
cache or not. If the page is missing from cache, the fetch method will
return undef. If the page is in cache, that page will be returned, no
matter how old it is.

=item refresh 'always'

If a page is in the cache, the origin HTTP server is always checked for
a fresher copy

=item refresh <number>

The origin HTTP server is not contacted if the page is in cache
and the cached page was inserted within the last <number> days.
    Otherwise the server is checked for a fresher page.

=back

=cut

method fetch ($uri, $refresh="yearly") {

    my $refresh_lc = lc $refresh;

    carp '*W* no cache location therefore no caching of HTTP queries available'
        if not $_root_dir and $refresh_lc ne 'never';

    my $from_cache;
    my $content;

    if ($refresh_lc eq 'always') {
        ($from_cache, $content) = $self->_fetch_refresh_always($uri);
    }
    elsif ($refresh_lc eq 'never') {
        ($from_cache, $content) = $self->_fetch_refresh_never($uri);
    }
    elsif ($refresh_lc eq 'yearly') {
        my $cutoff_mtime = localtime->truncate( to => 'year' );
        ($from_cache, $content) = $self->_fetch_refresh_n_days($uri, $cutoff_mtime);
    } else {
        croak unless $refresh =~ m{ \A \d+ \Z }xms;
        my $cutoff_mtime = localtime->truncate( to => 'day') - ( $refresh * $ONE_DAY );
        ($from_cache, $content) = $self->_fetch_refresh_n_days($uri, $cutoff_mtime);
    }

    return ($from_cache, $content);
}

=head2 load ($uri)

Load a previously fetched and stored $uri from the file cache and 
returns the content.  Uses Path::Tiny->slurp_utf8, which will lock 
the file during the operation and which uses a binmode of 
:unix:encoding(UTF-8) for platform portability of the files.

=cut

method load ($uri) {
    my $file = $self->_path_to_key($uri);

    if ( defined $file && -f $file ) {
        return _read_file($file);
    } else {
        return undef;
    }
}

=head2 store ($uri, $content)

Stores content obtained from a URI using fetch() into a file in the 
cache.  The filename is derived from the tail end of the URI. 

Uses Path::Tiny->spew_utf8, which writes data to the file atomically. 
The file is written to a temporary file in the cache directory, then 
renamed over the original. 

A binmode of :unix:encoding(UTF-8) (i.e. PerlIO::utf8_strict) is 
used, unless Unicode::UTF8 0.58+ is installed. In that case, the content
will be encoded by Unicode::UTF8 and written using spew_raw.

The idea is to store data in a platform-neutral fashion, so cached
files can be used for unit testing on multiple platforms.

=cut

method store ($uri, $content) {

    croak "*E* cache directory doesn't exist: " . $_root_dir
        unless -d $_root_dir;

    my $store_file = $self->_path_to_key($uri);
    return if not defined $store_file;

    # path($dir)->make_path( $dir, mode => $_dir_create_mode )
        # if not -d $dir;

    _write_file( $store_file, $content );
}

=item remove ($uri)

Remove the cache file associated with this URI.

=cut

method remove ($uri) {
    my $file = $self->_path_to_key($uri)
        or return undef;
    unlink($file);
}

# method clear_station_cache () {
    # delete the station list and inventory files in the cache
# }

# method purge_cache($percent=80) {
    # delete $percent % of data files based on oldest access time
# }


#---------------------------------------------------------------------
# Private methods
#---------------------------------------------------------------------

method _fetch_refresh_never ($uri) {
    # use the cache only
    my $key = $self->_uri_to_key($uri);
    my $content = $self->load($key);
    return ($FROM_CACHE, $content);
}

method _fetch_refresh_always ($uri) {
    # check for a fresher copy on the server
    my $key = $self->_uri_to_key($uri);
    my $file = $self->_path_to_key($key);

    my $st = stat($file);

    # if we have a cached file, check to see if the page is newer
    if ($st) {
        my ($ctype, $doclen, $mtime, $exp, $svr) = head($uri)
            or croak '*E* unable to fetch header for: ' . $uri;

        if ($mtime > $st->mtime) {
            # page changed since it was cached
            my $content = get($uri);
            $self->store($key, $content) if $content;
            return ($FROM_URI, $content);
        } else {
            # page is unchanged, so use the cached file
            my $content = $self->load($key);
            return ($FROM_CACHE, $content);
        }
    }

    # there's no cached file, so get the page from the URI and cache it
    my $content = get($uri);
    $self->store($key, $content) if $content;
    return ($FROM_URI, $content);
}

method _fetch_refresh_n_days ($uri, $cutoff_mtime) {
    # check whether the cache or page is older than N days
    # if the cache file is younger than N days ago, use it
    # otherwise get the latest page from the server
    # check the server if the file is older than this year

    my $key = $self->_uri_to_key($uri);
    my $file = $self->_path_to_key($key);

    my $st = stat($file);

    if ($st and $st->mtime >= $cutoff_mtime) {
        # the cached file we have is at or new than the cutoff, so we'll use it
        my $content = $self->load($key);
        return ($FROM_CACHE, $content);
    }

    # get the mtime for the URI
    my ($ctype, $doclen, $mtime, $exp, $svr) = head($uri)
        or croak '*E* unable to fetch header for: ' . $uri;

    # our cached file is older than the cutoff, but if it's up to date
    # with the web page then we can use it
    if ($st and $st->mtime >= $mtime) {
        # web page hasn't changed since it was cached. so we'll use it
        my $content = $self->load($key);
        return ($FROM_CACHE, $content);
    }

    # there's no cached file, or the cached file is out of date, so
    # we get the page from the URI and cache it
    my $content = get($uri);
    $self->store($key, $content) if $content;
    return ($FROM_URI, $content);
}

method _uri_to_key ($uri) {
    my @parts = split '/', $uri;
    my $key = $parts[-1];  # use the last part as the key

    # this transformation is for testing using CPAN pages and is not
    # necessary for the NOAA GHCN pages we actually deal with
    $key =~ s{ [:] }{}xmsg;

    return $key;
}

method _path_to_key ($uri) {
    return undef if !defined($uri);

    my $key = $self->_uri_to_key( $uri );

    my $filepath = path($_root_dir)->child($key)->stringify;

    return $filepath;
}

######################################################################
# Private subroutines
######################################################################

sub _read_file ( $file ) {
    return path($file)->slurp_utf8;
}

sub _write_file ( $file, $data ) {
    return path($file)->spew_utf8( $data );
}


1;

__END__

=head1 AUTHOR

Gary Puckering (jgpuckering@rogers.com)

=head1 LICENSE AND COPYRIGHT

Copyright 2022, Gary Puckering

=cut
