package Hastr;
use 5.008001;
use strict;
use warnings;
use List::Util qw(shuffle);
use Hastr::File;
use Path::Tiny qw(path);
use Hastr::Client;

our $VERSION = '0.1.0';

sub new {
    my ($class, $args) = @_;
    my %args = %$args;
    $args{client} = Hastr::Client->new();
    return bless \%args, $class;
}

sub client { shift->{client} }

sub about {
    my ($self, $c) = @_;

    $c->render(text => 'This is ' . __PACKAGE__ . " $VERSION.");
}

sub get_file {
    my ($self, $c) = @_;

    my $file = Hastr::File->new(
        hash => $c->param('hash'),
        root => $self->{root}
    );

    return $c->reply->static($file->name) if $file->exists();

    for my $node (shuffle @{ $self->{others} }) {
        if ($self->client->exists_file($node, $file->name)) {
            return $c->redirect_to("http://$node/file/" . $file->hash);
        }
    }

    $c->render(text => 'Not found', status => 404);
}

sub post_file {
    my ($self, $c) = @_;

    my $backup_node = $c->req->param('backup-node');

    my $file = Hastr::File->new(
        hash    => $c->param('hash'),
        root    => $self->{root},
        backups => $self->{backups},
    );

    my $upload = $c->req->upload('file');

    if ($file->exists()) {
        return $c->render(text => 'Exists', status => 409);
    }

    if ($backup_node) {
        $file->write($upload, $backup_node);
        return $c->render(text => 'Backed-up');
    }
    else {
        my $retries;
        while (1) {
            $backup_node = $self->pick_other_node();
            my $res = $self->client->post_file(
                node        => $node,
                hash        => $file->hash,
                asset       => $upload->asset,
                backup_node => $self->{me},
            );

            return $c->render(text => 'Exists', status => 409)
                if $res->code == 409;
            last
                if $res->code == 200;
            die 'Failed to create backup on another node'
                if ++$retries > 3;
            sleep 1
        }
        $file->write($upload, $backup_node);
        $c->render(text => 'Written and backed-up');
    }
}

sub delete_file {
    my ($self, $c) = @_;

    my $backup_node = $c->req->param('backup-node');

    my $file = Hastr::File->new(
        hash    => $c->param('hash'),
        root    => $self->{root},
        backups => $self->{backups},
    );

    $file->delete($backup_node);
}

sub change_backup_node_of_random_file {
    my ($self, $new_backup_node) = @_;

    # pick random mirror
    my $old_backup_node = $self->pick_other_node();
    $new_backup_node //= $self->pick_other_node([$old_backup_node]);

    # from the old backup node, pick random file
    my $file = Hastr::File->random_from_backup_node(
        $old_backup_node,
        root    => $self->{root},
        backups => $self->{backups},
    );

    # post the file to the new backup node
    my $res = $self->client->post_file(
        node        => $node,
        hash        => $file->hash,
        path        => $file->path,
        backup_node => $self->{me},
    );

    # delete the file from the old backup node
    my $res = $self->client->delete($node, $file->hash, $self->{me});

    # move the symlink from the old backup dir to the new backup dir
    #TODO: error handling
    $file->backup_path($old_backup_node)->remove();
    $file->create_backup_symlink($new_backup_node);
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

