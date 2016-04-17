requires 'perl', '5.008001';

requires 'Pod::Usage';
requires 'HTTP::Tiny';
requires 'Linux::Distribution';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Test::MonkeyMock';
};

