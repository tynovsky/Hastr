package Hastr;
use 5.008001;
use strict;
use warnings;
use List::Util qw(shuffle);
use Hastr::File;

our $VERSION = '0.1.0';

sub new {
    my ($class, $args) = @_;
    my %args = %$args;
    $args{ua} = Mojo::UserAgent->new();
    return bless \%args, $class;
}

sub about {
    my ($self, $c) = @_;

    $c->render(text => 'This is ' . __PACKAGE__ . " $VERSION.");
}

sub get_file {
    my ($self, $c) = @_;

    my $file = Hastr::File->new(hash => $c->param('hash'), root => $self->{root});

    return $c->reply->static($file->name) if $file->exists();

    for my $node (shuffle @{ $self->{others} }) {
        if ($self->{ua}->head($node . '/' . $file->name)->res->code == 200) {
            return $c->redirect_to("http://$node/file/" . $file->hash);
        }
    }

    $c->render(text => 'Not found', status => 404);
}

sub post_file {
    my ($self, $c) = @_;

    my $from = $c->req->param('from');

    my $file = Hastr::File->new(
        root => $self->{root},
        backups => $self->{backups},
        hash => $c->param('hash'),
        upload => $c->req->upload('file'),
    );

    if ($file->exists()) {
        return $c->render(text => 'Already exists', status => 409);
    }

    if ($from) {
        $file->write($from);
    }
    else {
        my ($node, $retries);
        while (1) {
            $node = $self->pick_other_node();
            my $tx = $self->{ua}->post(
                "$node/file/" . $file->hash . "?from=$self->{me}"
                => form
                => { file => { file => $file->upload->asset } }
            );

            return $c->render(text => 'Already exists', status => 409)
                if $tx->res->code == 409;
            last
                if $tx->res->code == 200;
            die 'Failed to create backup on another node'
                if ++$retries > 3;
            sleep 1
        }
        $file->write($node);
    }

    $c->render(text => 'Written to ' . $from ? 1 : 2);
}

sub pick_other_node {
    my ($self, $except) = @_;
    my %nodes;
    $nodes{$_} = 1    for @{ $self->{others} };
    delete $nodes{$_} for @{ $except };
    my @nodes = keys %nodes;
    return $nodes[rand @nodes];
}


1;
__END__

=encoding utf-8

=head1 NAME

Hastr - It's new $module

=head1 SYNOPSIS

    use Hastr;

=head1 DESCRIPTION

Hastr is ...

=head1 LICENSE

Copyright (C) Miroslav Tynovsky.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Miroslav Tynovsky E<lt>tynovsky@avast.comE<gt>

=cut

