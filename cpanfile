requires 'perl', '5.008001';

requires 'Pod::Usage';
requires 'Pod::Find';
requires 'HTTP::Tiny';
requires 'Linux::Distribution';
requires 'YAML::Tiny';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Test::MonkeyMock';
};
