#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Path::Tiny;
use FindBin qw($Bin);

use lib "$Bin/../../lib";
use Hastr::Client;

system <<'EOI';
bash -c '
cd ../../;
tmux new-session -d -s hastr
for i in {0..4}; do
    tmux new-window -n $i \
        "PERL5LIB=$PERL5LIB:lib MOJO_CONFIG=hastr300$i.conf perl script/hastr.pl daemon --listen http://*:300$i; echo "ENDED"; read key";
done
'
EOI

# generate random files

my $multiplier = 10;
my $min = 1_000;
my $max = 1_000_000;
my $size_limit = 1_000_000;

my $number_of_generated_files = 0;
my $total_generated_size = 0;

my $current_size = $min;
while ($current_size <= $max) {
    my $generated_size = 0;
    while ($generated_size < $size_limit) {
        system("
            dd if=/dev/urandom of=file.dat bs=$current_size count=1 2>/dev/null;
            mv file.dat \$(sha256sum file.dat | cut -f1 -d' ').dat;
        ");
        $generated_size += $current_size;
        $number_of_generated_files++;
    }
    $total_generated_size += $generated_size;
    $current_size *= $multiplier;
}

note "total size of generated files: $total_generated_size";

# post all the files (measure time)
my $time_taken = -time;
my $client = Hastr::Client->new();
for my $file (glob('*.dat')) {
    $client->post_file(
        node => 'localhost:300' . int(rand(5)),
        path => $file,
        hash => $file =~ s/\.dat$//r,
    );
};
$time_taken += time;
note "posting took $time_taken seconds";

# get all the files (measure time)
$time_taken = -time;
for my $file (glob('*.dat')) {
    my $node = 'localhost:300' . int(rand(5));
    my $res = $client->get_file($node, $file =~ s/\.dat$//r);
    path("$file.gotten")->spew($res->body);
}
$time_taken += time;
note "getting took $time_taken seconds";

# check if gotten all the files (prove the posting was succesful)
my $number_of_correct_files = 0;
for my $file (glob('*.dat')) {
    $number_of_correct_files += (system("cmp $file $file.gotten") == 0);
    unlink "$file.gotten";
    unlink "$file";
}

is(
    $number_of_correct_files,
    $number_of_generated_files,
    "all $number_of_generated_files files were transfered correctly"
);

system("tmux kill-session -t hastr");
system("rm -rf /tmp/hastr300[0-4]");

done_testing;


# kill one node

# get all the files (measure time)

# check if gotten all the files (prove all the files were there twice)

# tell remaining nodes that one is gone. tell them to recover the files on themselves, without dead node replacement (measure time)

# kill another node

# get all the files (measure time)

# check if gotten all the files (prove the recover was succesful)

# add one node

# tell nodes there is one new. tell them to replace the dead node (measure time)

# add one node

# tell nodes there is one new. tell them to rebalance (measure time)

# check they all have same remaining disk space
