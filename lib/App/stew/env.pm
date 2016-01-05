package App::stew::env;

use strict;
use warnings;

use Config;
use Linux::Distribution;
use App::stew::util qw(debug slurp_file);

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    return $self;
}

sub setup {
    my $self = shift;

    _unshift_env(PATH => "$ENV{PREFIX}/bin");

    _unshift_env(LIBPATH         => "$ENV{PREFIX}/lib");
    _unshift_env(LIBRARY_PATH    => "$ENV{PREFIX}/lib");
    _unshift_env(LD_LIBRARY_PATH => "$ENV{PREFIX}/lib");

    _unshift_env(CPATH              => "$ENV{PREFIX}/include");
    _unshift_env(C_INCLUDE_PATH     => "$ENV{PREFIX}/include");
    _unshift_env(CPLUS_INCLUDE_PATH => "$ENV{PREFIX}/include");
}

sub detect_os {
    my $self = shift;

    my $os = $self->_osname;

    if ($os eq 'linux') {
        my $dist_name = Linux::Distribution::distribution_name() // 'generic';
        my $dist_version = eval { Linux::Distribution::distribution_version() };

        if ($dist_version && $dist_version =~ m/^(\d+(?:\.\d+)?)/) {
            $dist_version = $1;
        }
        else {
            $dist_version = undef;
        }

        $os .= "-$dist_name";
        $os .= "-$dist_version" if $dist_version;
    }

    return $os;
}

sub detect_arch {
    my $self = shift;

    my $arch;

    chomp($arch //= `uname -m`);
    $arch = lc $arch;

    return $arch;
}

sub _osname { $^O }
sub _root   { '/' }

sub _unshift_env {
    my ($var, $value) = @_;

    if ($ENV{$var}) {
        $ENV{$var} = "$value:$ENV{$var}";
    }
    else {
        $ENV{$var} = $value;
    }

    debug "Setting ENV{$var}=$ENV{$var}";
}

1;
