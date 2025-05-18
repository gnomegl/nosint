package Nosint::Formatter;

use strict;
use warnings;
use Term::ANSIColor;

sub new {
    my ($class, %args) = @_;

    my $self = {
        json_output => $args{json_output} || 0,
        show_not_found => $args{show_not_found} || 0,
    };

    bless $self, $class;
    return $self;
}

sub format_output {
    my ($self, $data, $json_str) = @_;

    if ($self->{json_output}) {
        print "$json_str\n";
        return;
    }

    my $status = $data->{status} || "";
    my $timestamp = $data->{timestamp} || "";
    my $message = $data->{message} || "";

    if ($status eq "connecting") {
        $self->print_status_line($status, $message, $timestamp);
    }
    elsif ($status eq "plugins_discovered") {
        $self->print_status_line($status, $message, $timestamp);
        print "  Found: ", colored($data->{total_plugins} . " plugins", "bright_white"), "\n";
    }
    elsif ($status eq "search_started") {
        $self->print_status_line($status, $message, $timestamp);
    }
    elsif ($status eq "batch_processing") {
        foreach my $update (@{$data->{updates}}) {
            $self->print_progress($update->{plugin_name}, $update->{current}, $update->{total});
        }
    }
    elsif ($status eq "batch_errors") {
        return unless $self->{show_not_found};

        foreach my $error (@{$data->{errors}}) {
            $self->print_error($error->{plugin_name}, $error->{message});
        }
    }
    elsif ($status eq "batch_results") {
        foreach my $result (@{$data->{results}}) {
            $self->print_result($result);
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
    my ($self, $status, $message, $timestamp) = @_;

    my $status_color = "cyan";
    if ($status eq "completed") {
        $status_color = "green";
    } elsif ($status eq "error") {
        $status_color = "red";
    }

    my $time_str = $self->format_timestamp($timestamp);
    print colored($time_str, "bright_black"), " ";
    print colored("[" . uc($status) . "]", $status_color), " ";
    print "$message\n";
}

sub print_progress {
    my ($self, $plugin_name, $current, $total) = @_;

    my $percent = int(($current / $total) * 100);
    print colored("\r[PROCESSING]", "cyan"), " ";
    print "Plugin ", colored($plugin_name, "bright_white"), " ";
    print "($current/$total) ";
    print colored("$percent%", "yellow");
}

sub print_error {
    my ($self, $plugin_name, $message) = @_;

    print "\r", " " x 80, "\r";
    print colored("[NOT FOUND]", "red"), " ";
    print "Plugin ", colored($plugin_name, "bright_white"), ": ";
    print "$message\n";
}

sub print_result {
    my ($self, $result) = @_;

    my $plugin_name = $result->{plugin_name};
    my $data = $result->{data};
    my $execution_time = $result->{execution_time};

    print "\r", " " x 80, "\r";
    print colored("[FOUND]", "green"), " ";
    print "Plugin ", colored($plugin_name, "bright_white"), " ";
    print "($execution_time)\n";

    if (ref $data eq 'ARRAY') {
        print "  Source: ", colored($plugin_name, "bright_cyan"), "\n";
        print "  Records Found: ", colored(scalar(@$data), "bright_white"), "\n\n";
        
        foreach my $idx (0..$#$data) {
            my $record = $data->[$idx];
            
            print "    ", colored("Record #" . ($idx + 1), "bright_white"), "\n";
            print "    ", colored("-" x 40, "bright_black"), "\n";
            
            if (ref $record eq 'HASH') {
                foreach my $section (sort keys %$record) {
                    if (ref $record->{$section} eq 'HASH') {
                        print "    ", colored("$section:", "bright_cyan"), "\n";
                        foreach my $key (sort keys %{$record->{$section}}) {
                            next if $key =~ /^_/; # skip fields starting with underscore
                            my $value = $record->{$section}->{$key};
                            $value = defined $value ? $value : "[empty]";
                            print "      $key: ", colored($value, "bright_white"), "\n";
                        }
                    } else {
                        my $value = $record->{$section};
                        $value = defined $value ? $value : "[empty]";
                        print "    ", colored("$section:", "bright_cyan"), " ", 
                              colored($value, "bright_white"), "\n";
                    }
                }
            } elsif (ref $record eq 'ARRAY') {
                foreach my $i (0..$#$record) {
                    my $value = $record->[$i];
                    $value = defined $value ? $value : "[empty]";
                    print "    ", colored("Field " . ($i + 1) . ":", "bright_cyan"), " ", 
                          colored($value, "bright_white"), "\n";
                }
            } else {
                my $value = defined $record ? $record : "[empty]";
                print "    ", colored("Value:", "bright_cyan"), " ", 
                      colored($value, "bright_white"), "\n";
            }
            
            print "\n" unless $idx == $#$data;
        }
    }

    # standard fields
    else {
        if ($data->{meta} && $data->{meta}->{name}) {
            print "  Source: ", colored($data->{meta}->{name}, "bright_cyan"), "\n";
        }

        if ($data->{badges}) {
            print "  Badges: ", colored(join(", ", @{$data->{badges}}), "yellow"), "\n";
        }

        if ($data->{display}) {
            print "  Display Info:\n";
            $self->print_hash_content($data->{display}, 4);
        }

        if ($data->{recovery}) {
            print "  Recovery Info:\n";
            $self->print_hash_content($data->{recovery}, 4);
        }

        if ($data->{table}) {
            print "  Table Data:\n";
            $self->print_table($data->{table});
        }
    }

    print "\n";
}

sub print_hash_content {
    my ($self, $hash, $indent) = @_;
    return unless $hash;

    my $spaces = " " x $indent;
    foreach my $key (sort keys %$hash) {
        my $value = $hash->{$key};
        if (!defined $value) {
            $value = "null";
        } elsif (ref $value eq 'HASH') {
            print "$spaces$key:\n";
            $self->print_hash_content($value, $indent + 2);
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
    my ($self, $table) = @_;
    return unless $table;
    
    if ($table->{table_names} && ref $table->{headers} eq 'ARRAY' && ref $table->{headers}[0] eq 'ARRAY') {
        my @table_names = @{$table->{table_names}};
        my @header_sets = @{$table->{headers}};
        my @value_sets = @{$table->{values}};
        
        for my $table_idx (0..$#table_names) {
            print "    ", colored($table_names[$table_idx], "bright_white"), "\n";
            print "    ", colored("-" x 40, "bright_black"), "\n";
            
            my @headers = @{$header_sets[$table_idx]};
            my @values = ref $value_sets[$table_idx] eq 'ARRAY' ? @{$value_sets[$table_idx]} : ();
            
            foreach my $row_idx (0..$#values) {
                my $row = $values[$row_idx];
                
                for my $i (0..$#headers) {
                    my $header = $headers[$i];
                    my $cell = $row->[$i];
                    
                    if (defined $cell) {
                        if (ref $cell eq 'ARRAY') {
                            print "    ", colored($header . ":", "bright_cyan"), "\n";
                            foreach my $item (@$cell) {
                                print "      ", colored($item, "bright_white"), "\n";
                            }
                        } elsif (ref $cell eq 'HASH') {
                            print "    ", colored($header . ":", "bright_cyan"), "\n";
                            foreach my $k (sort keys %$cell) {
                                next if $k =~ /^_/; # skip fields starting with underscore
                                if (defined $cell->{$k} && $cell->{$k} ne "") {
                                    print "      $k: ", colored($cell->{$k}, "bright_white"), "\n";
                                }
                            }
                        } else {
                            my $value_str = $cell ne "" ? $cell : "[empty]";
                            print "    ", colored($header . ":", "bright_cyan"), " ", 
                                  colored($value_str, "bright_white"), "\n";
                        }
                    }
                }
                print "\n" unless $row_idx == $#values;
            }
            
            print "\n" unless $table_idx == $#table_names;
        }
    }
    elsif ($table->{headers} && $table->{values}) {
        my @headers = @{$table->{headers}};
        my @values = @{$table->{values}};
        
        foreach my $row_idx (0..$#values) {
            my $row = $values[$row_idx];
            
            print "    ", colored("Record #" . ($row_idx + 1), "bright_white"), "\n";
            print "    ", colored("-" x 40, "bright_black"), "\n";
            
            for my $i (0..$#headers) {
                my $header = $headers[$i];
                my $cell = $row->[$i];
                my $value_str = "";
                
                if (ref $cell eq 'HASH') {
                    print "    ", colored($header . ":", "bright_cyan"), "\n";
                    foreach my $k (sort keys %$cell) {
                        next if $k =~ /^_/; # skip fields starting with underscore
                        if (defined $cell->{$k} && $cell->{$k} ne "") {
                            print "      $k: ", colored($cell->{$k}, "bright_white"), "\n";
                        }
                    }
                } elsif (ref $cell eq 'ARRAY') {
                    print "    ", colored($header . ":", "bright_cyan"), "\n";
                    foreach my $item (@$cell) {
                        print "      ", colored($item, "bright_white"), "\n";
                    }
                } else {
                    $value_str = defined $cell ? $cell : "[empty]";
                    print "    ", colored($header . ":", "bright_cyan"), " ", 
                          colored($value_str, "bright_white"), "\n";
                }
            }
            print "\n" unless $row_idx == $#values;
        }
    }
}

sub format_timestamp {
    my ($self, $timestamp) = @_;
    return $timestamp if !$timestamp;

    if ($timestamp =~ /T(\d+:\d+:\d+)/) {
        return $1;
    }
    return $timestamp;
}

sub print_info {
    my ($self, $message) = @_;
    print colored($message, "cyan"), "\n";
}

1;
