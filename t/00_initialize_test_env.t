# Test suite for GHCN

use strict;
use warnings;
use v5.18;

use Test::More tests => 1;

use Config;
use FindBin;
use File::Path  qw( remove_tree );

my $cachedir = $FindBin::Bin . '/ghcn_cache/ghcn';

my $opt = shift @ARGV // '';

my $errors_aref;

my $is_Win32_x64 = $Config{archname} =~ m{ \A MSWin32-x64 }xms;

# TODO: provide a portable caching solution

# Clean out the cache if this script is run with command line argument 
# 'clean'.  To invoke this option when running 'prove', use the
# arisdottle; i.e. prove :: clean
#
# Until these cache files can be made platform portable, we'll also
# clean the cache when we are not on Windows x64.
#
if ( $opt =~ m{ [-]?clean }xmsi ) {
#if ( !$is_Win32_x64 or $opt =~ m{ [-]?clean }xmsi ) {
    if (-e $cachedir) {
        remove_tree( $cachedir, 
            {   safe => 1, 
                error => \$errors_aref,
            } 
        );
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