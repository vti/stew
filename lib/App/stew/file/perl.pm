package App::stew::file::perl;

use strict;
use warnings;

use YAML::Tiny ();
use App::stew::util qw(slurp_file error listify);

sub new {
    my $class = shift;
    my (%params) = @_;

    my $file    = $params{file};
    my $content = $params{content};

    my $stew_class = $class->_sandbox($file, $content);
    return $stew_class->new;
}

sub _sandbox {
    my $self = shift;
    my ($file, $content) = @_;

    my $class_name = 'stew::_build_' . _rand_str();

    my $package = <<"EOP";
    package $class_name;
    use strict;
    use warnings;
    use App::stew::util qw(cmd);
    my \$name;
    my \$version;
    my \$package;
    my \$file;
    my \@files;
    my \$url;
    my \@depends;
    my \@flags;
    my \@os;

    sub new {
        my \$class = shift;

        my \$self = {};
        bless \$self, \$class;

        return \$self;
    }

    sub name    { \$name }
    sub version { \$version }
    sub package { \$package }
    sub file    { \$file }
    sub files   { \@files }
    sub url     { \$url }
    sub depends { \@depends }
    sub flags   { \@flags }
    sub os      { \@os }

    my \$phases = {};
    sub prepare(&)  { \$phases->{prepare}  = shift }
    sub build(&)    { \$phases->{build}    = shift }
    sub install(&)  { \$phases->{install}  = shift }
    sub cleanup(&)  { \$phases->{cleanup}  = shift }

    sub phase { \$phases->{\$_[1]} }

    sub is {
        my \$self = shift;
        my (\$flag) = \@_;

        return !!grep { \$_ eq \$flag } \$self->flags;
    }

    sub run {
        my \$self = shift;
        my (\$phase) = \@_;

        if (\$phases->{\$phase}) {
            my \@commands = \$phases->{\$phase}->();

            cmd(\@commands);
        }

        return;
    }
    $content
    1;
EOP

    eval $package or error("Error compiling '$file': $@");

    return $class_name;
}

sub _rand_str {
    my @alpha = ('0' .. '9', 'a' .. 'z', 'A' .. 'Z');
    my $str = '';

    $str .= $alpha[rand($#alpha)] for 1 .. 16;

    return $str;
}

1;
