#!/usr/bin/env perl

use strict;
use warnings;
use lib 'lib';
use Nosint::CLI;

exit Nosint::CLI->new->run();
