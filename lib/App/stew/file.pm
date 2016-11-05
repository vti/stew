package App::stew::file;

use strict;
use warnings;

use YAML::Tiny ();
use App::stew::util qw(slurp_file error listify);

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

    if ($content =~ m/^---/) {
        $content = $class->_parse_yaml($content);
    }

    my $stew_class = $class->_sandbox($stew_file, $content);
    my $stew = $stew_class->new;

    $CACHE{"$stew_file"} = $stew;

    return $stew;
}

sub _sandbox {
    my $self = shift;
    my ($file, $content) = @_;

    my $class_name = 'stew::_build_' . _rand_str();

    my $package = <<"EOP";
    package $class_name;
    use strict;
    use warnings;
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
            return \$phases->{\$phase}->()
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

sub _parse_yaml {
    my $class = shift;
    my ($content) = @_;

    my $yaml = YAML::Tiny->read_string($content);
    $yaml = $yaml->[0];

    $yaml->{PREFIX}  = '$ENV{PREFIX}';
    $yaml->{DESTDIR} = '$ENV{DESTDIR}';
    $yaml->{OS}      = $ENV{STEW_OS};
    $yaml->{ARCH}    = $ENV{STEW_ARCH};

    $yaml = _walk(
        $yaml,
        sub {
            return unless defined $_[0];

            $_[0] =~ s/\$\{([_a-zA-Z0-9]+)\}/defined $yaml->{$1} ? $yaml->{$1} : ''/ge;

            return $_[0];
        }
    );

    $content = '';

    for my $key (qw/name version package/) {
        if (my $value = $yaml->{$key}) {
            $content .= qq{\$$key = "$value";\n};
        }
    }

    my @sources = listify $yaml->{sources};
    if (@sources == 1) {
        $content .= qq{\$file = "$sources[0]";\n};
    }
    else {
        $content .=
          qq{\$files = ("} . join(', ', map { qq{"$_"} } @sources) . qq{");\n};
    }

    if (my $depends = $yaml->{depends}) {
        my @depends = listify $depends;

        $content .=
            qq{\@depends = (}
          . join(', ', map { qq{"$_"} } @depends)
          . qq{);\n};
    }

    foreach my $phase (qw/prepare build install cleanup/) {
        if (my $commands = $yaml->{$phase}) {
            $content .= "$phase {\n";
            $content .= join(",\n", map { s/^\s+//; s/\s+$//; qq{    "$_"} } @$commands);
            $content .= "\n};\n";
        }
    }

    return $content;
}

sub _walk {
    my ($tree, $cb) = @_;

    unless (ref $tree) {
        $tree = $cb->($tree);
        return $tree;
    }

    if (ref $tree eq 'HASH') {
        foreach my $key (keys %$tree) {
            $tree->{$key} = _walk($tree->{$key}, $cb);
        }
        return $tree;
    }
    elsif (ref $tree eq 'ARRAY') {
        foreach my $value (@$tree) {
            $value = _walk($value, $cb);
        }
        return $tree;
    }
    else {
        die 'Unexpected ref=' . ref($tree);
    }

}
1;
