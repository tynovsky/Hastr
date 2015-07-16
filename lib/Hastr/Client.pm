package Hastr::Client;
use 5.008001;
use strict;
use warnings;
use Mojo::UserAgent;
use Mojo::Asset::File;

sub new {
    my ($class, $args) = @_;
    my %args = %{$args // {}};
    $args{ua} = Mojo::UserAgent->new(
        max_connecions => delete $args{max_connections} // 10,
        max_redirects  => delete $args{max_redirectes}  // 10,
    );
    return bless \%args, $class
}

sub post_file {
    my ($self, %args) = @_;
    #args: node, hash, (asset|path), [backup_node]

    if (!exists $args{asset}) {
        $args{asset} = Mojo::Asset::File->new(path => $args{path});
    }

    my $query_string = exists $args{backup_node}
        ? "?backup-node=$args{backup_node}"
        : '';

    my $tx = $self->{ua}->post(
        "http://$args{node}/file/$args{hash}$query_string"
        => form
        => { file => { file => $args{asset} } }
    );

    return $tx->res
}

sub get_file {
    my ($self, $node, $hash) = @_;

    my $tx = $self->{ua}->get("http://$node/file/$hash");

    return $tx->res
}

sub exists_file {
    my ($self, $node, $name) = @_;

    my $tx = $self->{ua}->head("$node/$name");

    return $tx->res->code == 200
}

sub delete_file {
    my ($self, $node, $hash, $backup_node) = @_;

    my $tx = $self->{ua}->delete("$node/file/$hash?backup-node=$backup_node");

    return $tx->res;
}

1;
