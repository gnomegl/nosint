#!/usr/bin/env perl

use strict;
use warnings;
use JSON;
use Term::ANSIColor;
use Getopt::Long;
use LWP::UserAgent;
use HTTP::Request;
use Time::HiRes qw(time);

my $json_output = 0;
my $help = 0;
my $target;
my $plugin_type;
my $cookie;
my $verbose = 0;

GetOptions(
    "json|j" => \$json_output,
    "help|h" => \$help,
    "target|t=s" => \$target,
    "plugin-type|p=s" => \$plugin_type,
    "cookie|c=s" => \$cookie
);

if ($help || (!$target && !$plugin_type)) {
    print_help();
    exit(0);
}

# Get cookie from environment variable if not provided as an argument
$cookie = $ENV{NOSINT_COOKIE} unless $cookie;
if (!$cookie) {
    print colored("Error: Cookie not provided via --cookie flag or NOSINT_COOKIE environment variable", "red"), "\n";
    print "Please provide your authentication cookie from nosint.org\n";
    exit(1);
}

my $url = "https://nosint.org/api/stream-search?target=$target&plugin_type=$plugin_type";

my $ua = LWP::UserAgent->new;
$ua->timeout(180); 
$ua->agent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36');

my $req = HTTP::Request->new(GET => $url);
$req->header('Accept' => 'text/event-stream');
$req->header('Accept-Language' => 'en-US,en;q=0.5');
$req->header('Accept-Encoding' => 'gzip, deflate, br, zstd');
$req->header('Cookie' => $cookie);
$req->header('Connection' => 'keep-alive');
$req->header('Cache-Control' => 'no-cache');

print colored("Starting search for $target with plugin type: $plugin_type\n", "cyan");

my $buffer = '';

my $response = $ua->request($req, sub {
    my ($data, $response, $protocol) = @_;
    
    $buffer .= $data;
    
    while ($buffer =~ s/^data: (.+)(\r?\n)+//m) {
        my $json_str = $1;
        process_data($json_str) if $json_str;
    }
});

if (!$response->is_success) {
    print colored("\nError connecting to API: ", "red"), $response->status_line, "\n";
    print "Response body: ", $response->content, "\n";
    print "\nThis could be due to cookie expiration or incorrect format.\n";
    print "Please check your cookie is correct and current.\n";
    exit(1);
}

sub process_data {
    my ($json_str) = @_;
    
    # skip empty lines
    return if $json_str =~ /^\s*$/;
    
    my $data;
    eval {
        $data = decode_json($json_str);
    };
    
    if ($@) {
        print STDERR colored("\nError parsing JSON: $@\n", "red");
        print STDERR "Raw data: $json_str\n";
        return;
    }
    
    if ($json_output) {
        print "$json_str\n";
    } else {
        format_output($data);
    }
}

sub format_output {
    my ($data) = @_;
    
    my $status = $data->{status} || "";
    my $timestamp = $data->{timestamp} || "";
    my $message = $data->{message} || "";
    
    if ($status eq "connecting") {
        print_status_line($status, $message, $timestamp);
    }
    elsif ($status eq "plugins_discovered") {
        print_status_line($status, $message, $timestamp);
        print "  Found: ", colored($data->{total_plugins} . " plugins", "bright_white"), "\n";
    }
    elsif ($status eq "search_started") {
        print_status_line($status, $message, $timestamp);
    }
    elsif ($status eq "batch_processing") {
        foreach my $update (@{$data->{updates}}) {
            print_progress($update->{plugin_name}, $update->{current}, $update->{total});
        }
    }
    elsif ($status eq "batch_errors") {
        foreach my $error (@{$data->{errors}}) {
            print_error($error->{plugin_name}, $error->{message});
        }
    }
    elsif ($status eq "batch_results") {
        foreach my $result (@{$data->{results}}) {
            print_result($result);
        }
    }
    elsif ($status eq "completed") {
        my $success_rate = sprintf("%.1f%%", ($data->{successful_plugins} / $data->{total_plugins}) * 100);
        print "\n", colored("SEARCH COMPLETED", "green"), " in ", 
              colored($data->{total_time}, "bright_white"), "\n";
        print "  Successful plugins: ", colored("$data->{successful_plugins}/$data->{total_plugins} ($success_rate)", "bright_white"), "\n";
        print "  Credits remaining: ", colored($data->{creditsLeft}, "bright_white"), "\n";
    }
    elsif ($status eq "stream_closed") {
        print colored("\nConnection closed", "yellow"), "\n";
        exit(0);
    }
}

sub print_status_line {
    my ($status, $message, $timestamp) = @_;
    
    my $status_color = "cyan";
    if ($status eq "completed") {
        $status_color = "green";
    } elsif ($status eq "error") {
        $status_color = "red";
    }
    
    my $time_str = format_timestamp($timestamp);
    print colored($time_str, "bright_black"), " ";
    print colored("[" . uc($status) . "]", $status_color), " ";
    print "$message\n";
}

sub print_progress {
    my ($plugin_name, $current, $total) = @_;
    
    my $percent = int(($current / $total) * 100);
    print colored("\r[PROCESSING]", "cyan"), " ";
    print "Plugin ", colored($plugin_name, "bright_white"), " ";
    print "($current/$total) ";
    print colored("$percent%", "yellow");
}

sub print_error {
    my ($plugin_name, $message) = @_;
    
    print "\r", " " x 80, "\r"; 
    print colored("[NOT FOUND]", "red"), " ";
    print "Plugin ", colored($plugin_name, "bright_white"), ": ";
    print "$message\n";
}

sub print_result {
    my ($result) = @_;
    
    my $plugin_name = $result->{plugin_name};
    my $data = $result->{data};
    my $execution_time = $result->{execution_time};
    
    print "\r", " " x 80, "\r"; 
    print colored("[FOUND]", "green"), " ";
    print "Plugin ", colored($plugin_name, "bright_white"), " ";
    print "($execution_time)\n";
    
    if ($data->{meta} && $data->{meta}->{name}) {
        print "  Source: ", colored($data->{meta}->{name}, "bright_cyan"), "\n";
    }
    
    if ($data->{badges}) {
        print "  Badges: ", colored(join(", ", @{$data->{badges}}), "yellow"), "\n";
    }
    
    if ($data->{display}) {
        print "  Display Info:\n";
        print_hash_content($data->{display}, 4);
    }
    
    if ($data->{recovery}) {
        print "  Recovery Info:\n";
        print_hash_content($data->{recovery}, 4);
    }
    
    if ($data->{table}) {
        print "  Table Data:\n";
        print_table($data->{table});
    }
    
    print "\n";
}

sub print_hash_content {
    my ($hash, $indent) = @_;
    return unless $hash;
    
    my $spaces = " " x $indent;
    foreach my $key (sort keys %$hash) {
        my $value = $hash->{$key};
        if (!defined $value) {
            $value = "null";
        } elsif (ref $value eq 'HASH') {
            print "$spaces$key:\n";
            print_hash_content($value, $indent + 2);
            next;
        } elsif (ref $value eq 'ARRAY') {
            if (scalar(@$value) > 0) {
                $value = join(", ", @$value);
            } else {
                $value = "[]";
            }
        } elsif ($value eq "") {
            $value = "[empty]";
        }
        
        print "$spaces$key: ", colored($value, "bright_white"), "\n";
    }
}

sub print_table {
    my ($table) = @_;
    return unless $table && $table->{headers} && $table->{values};
    
    my @headers = @{$table->{headers}};
    my @values = @{$table->{values}};
    
    print "    ", join(" | ", map { colored($_, "bright_cyan") } @headers), "\n";
    print "    ", colored("-" x 40, "bright_black"), "\n";
    
    foreach my $row (@values) {
        my @formatted_row;
        foreach my $cell (@$row) {
            if (ref $cell eq 'HASH') {
                my @parts;
                foreach my $k (sort keys %$cell) {
                    next if $k =~ /^_/; # skip fields starting with underscore
                    push @parts, "$k: $cell->{$k}" if defined $cell->{$k} && $cell->{$k} ne "";
                }
                push @formatted_row, join(", ", @parts);
            } else {
                push @formatted_row, $cell;
            }
        }
        print "    ", join(" | ", @formatted_row), "\n";
    }
}

sub format_timestamp {
    my ($timestamp) = @_;
    return $timestamp if !$timestamp;
    
    if ($timestamp =~ /T(\d+:\d+:\d+)/) {
        return $1;
    }
    return $timestamp;
}

sub print_help {
    print <<EOF;
Usage: $0 --target EMAIL --plugin-type TYPE [options]

Required arguments:
  --target, -t EMAIL          Target email address to search
  --plugin-type, -p TYPE      Plugin type (e.g., 'email')

Options:
  --cookie, -c COOKIE         Authentication cookie for nosint.org
  --json, -j                  Output in JSONL format
  --help, -h                  Show this help message
  --show-not-found          Show not found results (default: off)

Environment variables:
  NOSINT_COOKIE               Authentication cookie (if not provided with --cookie)

Example:
  Set the authentication cookie in environment
  export NOSINT_COOKIE='next-auth.csrf-token=value; next-auth.callback-url=value; next-auth.session-token=value'
  
  Run the search
  $0 --target user\@example.com --plugin-type email
  
  Alternative: Provide cookie directly
  $0 --target user\@example.com --plugin-type email --cookie 'next-auth.csrf-token=value; next-auth.callback-url=value; next-auth.session-token=value'
EOF
}
