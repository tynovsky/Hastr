package Hastr::File;
use 5.008001;
use strict;
use warnings;
use Path::Tiny;

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

    return Path::Tiny::path($self->{root} . '/' . $self->name);
}

sub write {
    my ($self, $backup_node) = @_;

    $self->filepath->parent->mkpath();
    $self->upload->move_to($self->filepath);

    my $backup = Path::Tiny::path($self->{backups} . '/' . $backup_node);
    $backup->parent->mkpath();
    $backup->append([$self->{hash}]);
}

sub exists {
    return shift->filepath->exists()
}

1;
