package Hastr::File;
use 5.008001;
use strict;
use warnings;
use Path::Tiny qw();

sub new {
    my ($class, %args) = @_;
    return bless \%args, $class;
}

sub random_from_backup_node {
    my ($class, $backup_node, %args) = @_;

    my $self = $class->new(%args);

    my $path = glob($self->backups . '/' . $backup_node);
    for (1 .. 4) { #4 levels deep = 3 levels of dirs, then 1 file
        my @files = glob("$path/*");
        $path     = $files[rand @files];
    }

    $self->{hash} = Path::Tiny::path($path)->basename =~ s/[.]dat$//r;

    return $self;
}

sub root    { shift->{root}    }
sub backups { shift->{backups} }
sub hash    { shift->{hash}    }

sub name {
    return (shift->{hash} =~ s{^(..)(..)(..)}{$1/$2/$3/$1$2$3}r) . '.dat';
}

sub path {
    my ($self) = @_;

    return Path::Tiny::path($self->root . '/' . $self->name)
}

sub backup_path {
    my ($self, $node) = @_;

    return Path::Tiny::path($self->backups . "/$node/" . $self->name)
}

sub write {
    my ($self, $upload, $backup_node) = @_;

    $self->filepath->parent->mkpath();
    $upload->move_to($self->filepath);
    $self->create_backup_symlink($backup_node);
}

sub create_backup_symlink {
    my ($self, $backup_node) = @_;

    my $backup_path = $self->backup_path($backup_node);
    $backup_path->parent->mkpath();
    symlink($self->filepath, $backup_path)
        or die "Failed to create symlink $backup_path: $!";
}

sub delete {
    my ($self, $node) = @_;

    $self->filepath->remove();
    $self->backup_path($node)->remove();

}

sub exists {
    return shift->filepath->exists()
}

1;

__END__
