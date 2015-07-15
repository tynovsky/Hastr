package Hastr::File;
use 5.008001;
use strict;
use warnings;
use Path::Tiny qw(path);

sub new {
    my ($class, %args) = @_;
    return bless \%args, $class;
}

sub root {
    return shift->{root}
}

sub hash {
    return shift->{hash}
}

sub upload {
    return shift->{upload}
}

sub name {
    return (shift->{hash} =~ s{^(..)(..)(..)}{$1/$2/$3/$1$2$3}r) . '.dat';
}

sub filepath {
    my ($self) = @_;

    return path($self->{root} . '/' . $self->name);
}

sub backup_path {
    my ($self, $node) = @_;

    return path($self->{backups} . '/' . $node . '/' . $self->name);
}

sub write {
    my ($self, $backup_node) = @_;

    my $filepath    = $self->filepath();
    my $backup_path = $self->backup_path($backup_node);

    $filepath->parent->mkpath();
    $self->upload->move_to($filepath);

    $backup_path->parent->mkpath();
    symlink($filepath, $backup_path)
        or die "Failed to create symlink $backup_path: $!";

}

sub delete {
    my ($self, $node) = @_;

    $self->filepath->remove()
    $self->backup_path($node)->remove();

}

sub exists {
    return shift->filepath->exists()
}

1;
