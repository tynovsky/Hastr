package Hastr;
use 5.008001;
use strict;
use warnings;

our $VERSION = '0.1.0';

sub new {
    my ($class, %conf) = @_;
    return bless \%conf, $class;
}

sub about {
    my ($self, $c) = @_;

    $c->render(template => 'about');
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

