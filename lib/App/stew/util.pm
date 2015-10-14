package App::stew::util;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw(info debug error slurp_file write_file cmd);

use Carp qw(croak);

sub debug {
    print STDERR @_, "\n" if $ENV{STEW_LOG_LEVEL};

    open my $fh, '>>', $ENV{STEW_LOG_FILE}
      or die "Can't open logfile '$ENV{STEW_LOG_FILE}': $!";
    print $fh @_, "\n";
    close $fh;
}

sub slurp_file {
    my ($file) = @_;

    local $/;
    open my $fh, '<', $file or _error("Can't read file '$file': $!");
    return <$fh>;
}

sub write_file {
    my ($file, $content) = @_;

    open my $fh, '>', $file or _error("Can't write file '$file': $!");
    print $fh $content;
    close $fh;
}

sub info {
    warn join(' ', @_) . "\n";
}

sub error {
    debug(@_);
    croak("ERROR: " . join(' ', @_));
}

sub cmd {
    return unless @_;

    my $cmd = join ' && ', @_;

    #my $redirect = $opt_verbose ? '' : ' > /dev/null';
    $cmd = "sh -c \"$cmd 2>&1 > /dev/null\" 2>&1 >> /dev/null";

    #warn $cmd;
    #_logn($cmd);

    #unless ($opt_dry_run) {
        my $exit = system($cmd);

        _error("Command failed: $cmd") if $exit;
    #}
}

1;
