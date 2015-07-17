#!/usr/bin/env perl

use Mojolicious::Lite;
use Hastr;

# load configuration

my $config = plugin 'Config';
my $hastr = 'Hastr'->new($config);

get  '/'           => sub { $hastr->about(@_)     };
get  '/file/:hash' => sub { $hastr->get_file(@_)  };
post '/file/:hash' => sub { $hastr->post_file(@_) };

app->static->paths([$config->{root}]);
app->start;

__DATA__

@@ not_found.development.html.ep
404 Not found

