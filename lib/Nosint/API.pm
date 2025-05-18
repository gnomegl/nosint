package Nosint::API;

use strict;
use warnings;
use JSON;
use LWP::UserAgent;
use HTTP::Request;
use Time::HiRes qw(time);

sub new {
    my ($class, %args) = @_;

    my $self = {
        cookie => $args{cookie},
        verbose => $args{verbose} || 0,
        formatter => $args{formatter},
        aggressive => $args{aggressive} || 0,
        buffer => '',
        ua => LWP::UserAgent->new,
    };

    $self->{ua}->timeout(180);
    $self->{ua}->agent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36');

    bless $self, $class;
    return $self;
}

sub search {
    my ($self, $target, $plugin_type) = @_;

    my $url = "https://nosint.org/api/stream-search?target=$target&plugin_type=$plugin_type";
    
    if ($self->{aggressive}) {
        $url .= "&report=true";
        $self->{formatter}->print_info("Aggressive search mode enabled - this will alert the target");
    }

    my $req = HTTP::Request->new(GET => $url);
    $req->header('Accept' => 'text/event-stream');
    $req->header('Accept-Language' => 'en-US,en;q=0.5');
    $req->header('Accept-Encoding' => 'gzip, deflate, br, zstd');
    $req->header('Cookie' => $self->{cookie});
    $req->header('Connection' => 'keep-alive');
    $req->header('Cache-Control' => 'no-cache');

    $self->{formatter}->print_info("Starting search for $target with plugin type: $plugin_type");

    my $response = $self->{ua}->request($req, sub {
        my ($data, $response, $protocol) = @_;

        $self->{buffer} .= $data;

        while ($self->{buffer} =~ s/^data: (.+)(\r?\n)+//m) {
            my $json_str = $1;
            $self->process_data($json_str) if $json_str;
        }
    });

    if (!$response->is_success) {
        $self->{formatter}->print_error(
            "Error connecting to API: " . $response->status_line . "\n" .
            "Response body: " . $response->content . "\n\n" .
            "This could be due to cookie expiration or incorrect format.\n" .
            "Please check your cookie is correct and current."
        );
        return 0;
    }

    return 1;
}

sub process_data {
    my ($self, $json_str) = @_;

    # skip empty lines
    return if $json_str =~ /^\s*$/;

    my $data;
    eval {
        $data = decode_json($json_str);
    };

    if ($@) {
        $self->{formatter}->print_error("Error parsing JSON: $@\nRaw data: $json_str");
        return;
    }

    $self->{formatter}->format_output($data, $json_str);
}

sub validate_auth {
    my ($self) = @_;
    return 0 unless $self->{cookie};
    my $valid = $self->{cookie} =~ /next-auth\.session-token=/;
    return $valid;
}

1;
