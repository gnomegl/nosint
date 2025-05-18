package Nosint::CLI;

use strict;
use warnings;
use Getopt::Long;
use Nosint::API;
use Nosint::Formatter;

sub new {
    my ($class) = @_;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub run {
    my ($self) = @_;

    my $options = $self->parse_options();

    return 0 if $options->{help};

    if ( !$options->{target} || !$options->{plugin_type} ) {
        $self->print_help();
        return 1;
    }

    my $formatter = Nosint::Formatter->new(
        json_output    => $options->{json_output},
        show_not_found => $options->{show_not_found},
    );

    $options->{cookie} = $ENV{NOSINT_COOKIE} unless $options->{cookie};

    if ( !$options->{cookie} ) {
        $formatter->print_error(
"Cookie not provided via --cookie flag or NOSINT_COOKIE environment variable"
        );
        print "Please provide your authentication cookie from nosint.org\n";
        return 1;
    }

    my $api = Nosint::API->new(
        cookie     => $options->{cookie},
        verbose    => $options->{verbose},
        formatter  => $formatter,
        aggressive => $options->{aggressive},
    );

    if ( !$api->validate_auth() ) {
        $formatter->print_error("Invalid authentication cookie format");
        print "Please check your cookie format and try again\n";
        return 1;
    }

    my $result = $api->search( $options->{target}, $options->{plugin_type} );

    return $result ? 0 : 1;
}

sub parse_options {
    my ($self) = @_;

    my %options = (
        json_output    => 0,
        help           => 0,
        verbose        => 0,
        show_not_found => 0,
        aggressive     => 0,
    );

    GetOptions(
        "json|j"          => \$options{json_output},
        "help|h"          => \$options{help},
        "target|t=s"      => \$options{target},
        "plugin-type|p=s" => \$options{plugin_type},
        "cookie|c=s"      => \$options{cookie},
        "verbose|v"       => \$options{verbose},
        "show-not-found"  => \$options{show_not_found},
        "aggressive|a"    => \$options{aggressive},
    );

    if ( $options{help} ) {
        $self->print_help();
    }

    return \%options;
}

sub print_help {
    my ($self) = @_;

    print <<EOF;
Usage: nosint.pl --target EMAIL --plugin-type TYPE [options]

Required arguments:
  --target, -t EMAIL          Target email address to search
  --plugin-type, -p TYPE      Plugin type (e.g., 'email')

Options:
  --aggressive, -a            Enable aggressive search, alerts user (default: off)
  --cookie, -c COOKIE         Authentication cookie for nosint.org
  --json, -j                  Output in JSONL format
  --help, -h                  Show this help message
  --show-not-found            Show not found results (default: off)
  --verbose, -v               Show verbose output

Environment variables:
  NOSINT_COOKIE               Authentication cookie (if not provided with --cookie)

Example:
  Set the authentication cookie in environment
  export NOSINT_COOKIE='next-auth.csrf-token=value; next-auth.callback-url=value; next-auth.session-token=value'

  Run the search
  nosint.pl --target user\@example.com --plugin-type email

  Alternative: Provide cookie directly
  nosint.pl --target user\@example.com --plugin-type email --cookie 'next-auth.csrf-token=value; next-auth.callback-url=value; next-auth.session-token=value'
EOF
}

1;
