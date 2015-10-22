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

    $self->{argv} = $params{argv};

    return $self;
}

sub run {
    my $self = shift;

    my $opt_base;
    GetOptionsFromArray($self->{argv}, "base=s" => \$opt_base)
      or die "error";

    error("--base is required") unless $opt_base;

    my $snapshot = App::stew::snapshot->new(base => $opt_base)->load;

    foreach my $key (sort keys %$snapshot) {
        print "$key\n";
    }
}

1;
