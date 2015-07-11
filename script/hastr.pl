#!/usr/bin/perl

use Mojolicious::Lite;

# load configuration
my %conf = (
    root        => '/tmp/hastr',
    port        => 8080,
    redundancy  => 2,
);

my $hastr = 'Hastr'->new(%conf);

get  '/'           => sub { $hastr->about(@_)     };
get  '/file/:hash' => sub { $hastr->get_file(@_)  };
post '/file/:hash' => sub { $hastr->post_file(@_) };

app->start;
