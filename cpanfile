requires 'perl', '5.008001';
requires 'Mojolicious';
requires 'Path::Tiny';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

