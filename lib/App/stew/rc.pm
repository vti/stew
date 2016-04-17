package App::stew::rc;

use strict;
use warnings;

use File::Spec;

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    return $self;
}

sub load {
    my $self = shift;

    my $file = '.stewrc';
    for ('.', $ENV{HOME}) {
        my $path = File::Spec->catfile($_, $file);

        return $self->parse($path) if -f $path;
    }

    return {};
}

sub parse {
    my $self = shift;
    my ($file) = @_;

    my @lines =
      do { open my $fh, '<', $file or die "Can't open '$file': $!"; <$fh> };

    my $section = '_';

    my %options;
    foreach my $line (@lines) {
        next unless defined $line && $line !~ m/^\s*#/;

        chomp $line;
        $line =~ s{^\s+}{};
        $line =~ s{\s+$}{};

        next unless length $line;

        if ($line =~ m/^\[(.*?)\]$/) {
            $section = $1;
            next;
        }

        my ($key, $value) = split /\s+/, $line, 2;

        $options{$section}->{$key} = $value;
    }

    return \%options;
}

1;
