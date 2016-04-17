package App::stew::cmd::help;

use strict;
use warnings;

use base 'App::stew::cmd::base';

use Pod::Find qw(pod_where);
use Pod::Usage qw(pod2usage);
use App::stew::cmdbuilder;

sub run {
    my $self = shift;
    my ($command) = @_;

    my $command_instance = App::stew::cmdbuilder->new->build($command);

    pod2usage(-input => pod_where({-inc => 1}, ref($command_instance)), -verbose => 2);
}

1;
__END__

=head1 NAME

stew help - command help

=head1 SYNOPSIS

stew help [command]

=head1 DESCRIPTION

B<help> prints command help.

=cut
