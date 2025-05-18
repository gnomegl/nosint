#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;

# Forward to the main script
exec("$FindBin::Bin/bin/nosint", @ARGV) or die "Could not execute bin/nosint: $!"; 