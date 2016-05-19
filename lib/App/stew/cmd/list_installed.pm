package App::stew::cmd::list_installed;

use strict;
use warnings;

use Getopt::Long qw(GetOptionsFromArray);
use App::stew::snapshot;
use App::stew::util qw(info debug error);

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    return $self;
}

sub run {
    my $self = shift;
    my (@argv) = @_;

    my $opt_base;
    my $opt_prefix;
    GetOptionsFromArray(
        \@argv,
        "base=s"   => \$opt_base,
        "prefix=s" => \$opt_prefix
    ) or die "error";

    error("--base is required") unless $opt_base;

    my $snapshot =
      App::stew::snapshot->new(base => $opt_base, prefix => $opt_prefix)->load;

    foreach my $key (sort keys %$snapshot) {
        next if $key eq '_';
        next if $snapshot->{$key}->{dependency};
        print "$key $snapshot->{$key}->{version}\n";
    }
}

1;
