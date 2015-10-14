package App::stew::env;

use strict;
use warnings;

sub setup {
    _unshift_env(PATH => "$ENV{PREFIX}/bin");

    _unshift_env(LIBPATH         => "$ENV{PREFIX}/lib");
    _unshift_env(LIBRARY_PATH    => "$ENV{PREFIX}/lib");
    _unshift_env(LD_LIBRARY_PATH => "$ENV{PREFIX}/lib");

    _unshift_env(CPATH              => "$ENV{PREFIX}/include");
    _unshift_env(C_INCLUDE_PATH     => "$ENV{PREFIX}/include");
    _unshift_env(CPLUS_INCLUDE_PATH => "$ENV{PREFIX}/include");
}

sub _unshift_env {
    my ($var, $value) = @_;

    if ($ENV{$var}) {
        $ENV{$var} = "$value:$ENV{$var}";
    }
    else {
        $ENV{$var} = $value;
    }
}

1;
