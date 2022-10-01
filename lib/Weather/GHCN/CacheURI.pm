# Weather::GHCN::CacheURI.pm - class for fetching from a URI, with file caching

## no critic (Documentation::RequirePodAtEnd)

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

BUILD ($cache_root) {
    $_root_dir = $cache_root;
}

method fetch ($uri, $refresh="yearly") {
    
    my $refresh_lc = lc $refresh;

    # refresh eq 'yearly':
    #   The origin HTTP server is contacted and the page refreshed if the 
    #   cached file has not been changed within the current year. The 
    #   rationale for this, and for this being the default, is that the GHCN 
    #   data for the current year will always be incomplete, and that will 
    #   skew any statistical analysis and so should normally be truncated.
    #   If the user needs the data for the current year, they should use a
    #   refresh value of 'always' or a number.

    # refresh eq 'never':
    #   The origin HTTP is never contacted, regardless of the page being in
    #   cache or not. If the page is missing from cache, the fetch method will
    #   return undef. If the page is in cache, that page will be returned, no
    #   matter how old it is.

    # refresh eq 'always':
    #   If a page is in the cache, the origin HTTP server is always checked for
    #   a fresher copy

    # refresh == <number>:
    #   The origin HTTP server is not contacted if the page is in cache 
    #   and the cached page was inserted within the last <number> days.  
    #   Otherwise the server is checked for a fresher page.

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

method _fetch_refresh_never ($uri) {
    # use the cache only
    my $key = $self->uri_to_key($uri);
    my $content = $self->load($key);
    return ($FROM_CACHE, $content);
}

method _fetch_refresh_always ($uri) {
    # check for a fresher copy on the server
    my $key = $self->uri_to_key($uri);
    my $file = $self->path_to_key($key);

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

    my $key = $self->uri_to_key($uri);
    my $file = $self->path_to_key($key);
    
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

method load ($key) {
    my $file = $self->path_to_key($key);

    if ( defined $file && -f $file ) {
        return read_file($file);
    } else {
        return undef;
    }
}

method store ($key, $data) {

    croak "*E* cache directory doesn't exist: " . $_root_dir
        unless -d $_root_dir;

    my $store_file = $self->path_to_key($key);
    return if not defined $store_file;

    # path($dir)->make_path( $dir, mode => $_dir_create_mode )
        # if not -d $dir;

    write_file( $store_file, $data );
}

method remove ($key) {
    my $file = $self->path_to_key($key)
        or return undef;
    unlink($file);
}


method uri_to_key ($uri) {
    my @parts = split '/', $uri;
    my $key = $parts[-1];  # use the last part as the key

    # this transformation is for testing using CPAN pages and is not
    # necessary for the NOAA GHCN pages we actually deal with
    $key =~ s{ [:] }{}xmsg;
    
    return $key;
}

method path_to_key ($uri) {
    return undef if !defined($uri);

    my $key = $self->uri_to_key( $uri );

    my $filepath = path($_root_dir)->child($key)->stringify;

    return $filepath;
}

# method clear_data_cache () {
    # delete the data files in the cache
# }

# method clear_station_cache () {
    # delete the station list and inventory files in the cache
# }

# method purge_cache($percent=80) {
    # delete $percent % of data files based on oldest access time
# }


sub read_file ( $file ) {
    return path($file)->slurp_utf8;
}

sub write_file ( $file, $data ) {
    path($file)->spew_utf8( $data );
}


1;

__END__

=pod

=head1 NAME

Weather::GHCN::CacheFile - File-based cache using one folder for all cache files

=head1 SYNOPSIS

    use Weather::GHCN::CacheFile;

    my $cache = Weather::GHCN::CacheFile->new(
        root_dir       => '/path/to/cache/root',
    );

=head1 DESCRIPTION

This cache driver stores data on the filesystem, so that it can be shared
between processes on a single machine, or even on multiple machines if using
NFS.

Each item is stored in its own file. By default, during a set, a temporary file
is created and then atomically renamed to the proper file. While not the most
efficient, it eliminates the need for locking (with multiple overlapping sets,
the last one "wins") and makes this cache usable in environments like NFS where
locking might normally be undesirable.

By default, the base filename is the key itself, with unsafe characters escaped
similar to URL escaping.

=head1 CONSTRUCTOR OPTIONS

When using this driver, the following options can be passed to CHI->new() in
addition to the L<CHI|general constructor options/constructor>.

=over

=item root_dir

The location in the filesystem that will hold the root of the cache.  Defaults
to a directory called 'chi-driver-file' under the OS default temp directory
(e.g. '/tmp' on UNIX). This directory will be created as needed on the first
cache set.

=item dir_create_mode

Permissions mode to use when creating directories. Defaults to 0775.

=item file_create_mode

Permissions mode to use when creating files, modified by the current umask.
Defaults to 0666.

=back

=head1 METHODS

=over

=item path_to_key ( $key )

Returns the full path to the cache file representing $key, whether or not that
entry exists. Returns the empty list if a valid path cannot be computed, for
example if the key is too long.

=item path_to_namespace

Returns the full path to the directory representing this cache's namespace,
whether or not it has any entries.

=back

=head1 TEMPORARY FILE RENAME

By default, during a set, a temporary file is created and then atomically
renamed to the proper file.  This eliminates the need for locking. You can
subclass and override method I<generate_temporary_filename> to either change
the path of the temporary filename, or skip the temporary file and rename
altogether by having it return undef.

=head1 SEE ALSO

L<CHI|CHI>

=head1 AUTHOR

Jonathan Swartz <swartz@pobox.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2021 by Jonathan Swartz.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
