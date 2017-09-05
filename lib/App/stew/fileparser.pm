package App::stew::fileparser;

use strict;
use warnings;

use App::stew::file::perl;
use App::stew::file::yml;
use App::stew::util qw(slurp_file);

my %CACHE;

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    return $self;
}

sub parse {
    my $class = shift;
    my ($stew_file) = @_;

    return $CACHE{"$stew_file"} if $CACHE{"$stew_file"};

    my $content = slurp_file($stew_file);

    my $stew;
    if ($content =~ m/^---/) {
        $stew =
          App::stew::file::yml->new(file => $stew_file, content => $content);
    }
    else {
        $stew =
          App::stew::file::perl->new(file => $stew_file, content => $content);
    }

    $CACHE{"$stew_file"} = $stew;

    return $stew;
}

1;
