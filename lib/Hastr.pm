package Hastr;
use 5.010;
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
                node        => $backup_node,
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

sub change_backup_node_of_file {
    my ($self, $file, $old_backup_node, $new_backup_node) = @_;

    my $res;
    # post the file to the new backup node
    $res = $self->client->post_file(
        node        => $new_backup_node,
        hash        => $file->hash,
        path        => $file->path,
        backup_node => $self->{me},
    );
    return $res->code if $res->code != 200;

    # delete the file from the old backup node
    $res = $self->client->delete($old_backup_node, $file->hash, $self->{me});
    warn 'failed to delete ' . $file->hash . "from $old_backup_node\n";

    # move the symlink from the old backup dir to the new backup dir
    try {
        $file->backup_path($old_backup_node)->remove();
    }
    catch {
        warn 'failed to remove symlink '
            . $file->backup_path($old_backup_node) . ": $_\n";
    };

    try {
        $file->create_backup_symlink($new_backup_node);
    }
    catch {
        warn 'failed to create backup symlink: '
            . $file->backup_path($new_backup_node) . ": $_\n";
    }

    return 200;
}

sub change_backup_node_of_random_file {
    my ($self, $old_backup_node, $new_backup_node) = @_;

    # pick random mirror
    $old_backup_node //= $self->pick_other_node();
    $new_backup_node //= $self->pick_other_node([$old_backup_node]);

    #FIXME
    #this might happen if called with
    # $old_backup_node = undef and $new_backup_node = some_node
    return if $old_backup_node eq $new_backup_node;

    # from the old backup node, pick random file
    my $file = Hastr::File->random_from_backup_node(
        $old_backup_node,
        root    => $self->{root},
        backups => $self->{backups},
    );

    return $self->change_backup_node_of_file(
        $file, $old_backup_node, $new_backup_node
    );
}

sub exclude_node { # move all backups from the node elsewhere
    my ($self, $node) = @_;

    while (my $file = Hastr::File->random_from_backup_node($node)) {
        my $new_backup_node = $self->pick_other_node([$node]);
        my $result = $self->change_backup_node_of_file(
            $file, $node, $new_backup_node
        );
        #TODO: co se soubory, ktere se nepovedly?
        # uz existuje => smazat u me.
        # jiny duvod => nedelat nic (priste se to zkusi zase na nahodny
        #   node, tak to treba vyjde). Pocitat neuspechy jednotlivych
        #   souboru. pri opakovanem neuspechu selhat.
    }
}

sub fill_new_node {
    my ($self, $node) = @_;

    while (1) {
        my $node_free = $self->client->get_info($node)->{percent_free};
        my $self_free = $self->info()->{percent_free};

      last if $node_free <= $self_free;

        $self->change_backup_node_of_random_file(undef, $node);
    }
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

