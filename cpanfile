# requires 'Nosint', '0.01';
# Core dependencies
requires 'perl', '5.010';  # Minimum Perl version requirement
requires 'strict';
requires 'warnings';

# JSON handling
requires 'JSON', '2.90';  # Modern JSON parser

# Command line argument parsing
requires 'Getopt::Long', '2.49';

# Terminal output formatting
requires 'Term::ANSIColor', '4.06';

# HTTP client libraries
requires 'LWP::UserAgent', '6.33';
requires 'HTTP::Request', '6.11';

# High-resolution timer
requires 'Time::HiRes', '1.9741';

# For development and testing
on 'develop' => sub {
    requires 'Perl::Critic', '1.138';
    requires 'Perl::Tidy', '20210111';
};

on 'test' => sub {
    requires 'Test::More', '1.302183';
    requires 'Test::Exception', '0.43';
    requires 'Test::MockObject', '1.20200122';
    requires 'Test::Warn', '0.36';
};
