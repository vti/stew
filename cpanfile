requires 'perl', '5.008001';

requires 'HTTP::Tiny';
requires 'Linux::Distribution';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

