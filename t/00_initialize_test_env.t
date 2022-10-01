# Test suite for GHCN

use strict;
use warnings;
use v5.18;

use Test::More tests => 1;

use Config;
use FindBin;
use lib $FindBin::Bin . '/../lib';

use Weather::GHCN::CacheURI;

my $cachedir = $FindBin::Bin . '/ghcn_cache';

my $clean = 1
    if grep { 'clean' eq lc $_ } @ARGV;;

my $errors_aref;

# Clean out the cache if this script is run with command line argument 
# 'clean'.  To invoke this option when running 'prove', use the
# arisdottle; i.e. prove :: clean
#
# Until these cache files can be made platform portable, we'll also
# clean the cache when we are not on Windows x64.
#
if ( $clean ) {
    if (-e $cachedir) {
        my $cache = Weather::GHCN::CacheURI->new($cachedir);
        my $errors_aref = $cache->clean_cache;
        my %errmsg;
        foreach my $href ($errors_aref->@*) {
            my @v = values $href->%*;
            foreach my $msg (@v) {
                $errmsg{$msg}++;
            }
        }
        while (my ($k,$v) = each %errmsg) {
            diag '*E* ' . $k . " ($v times)";
        }
        my $errcnt = $errors_aref->@*;
        
        ok $errcnt == 0, 'removed contents of cache ' . $cachedir;
            
    } else {
        ok 1, "*I* cache folder doesn't exist yet: " . $cachedir;
    }
} else {
    ok 1, 'using cache folder ' . $cachedir;
}