use utf8;
use strict;
use warnings;

package DR::Tarantool::SyncClient;
use base 'DR::Tarantool::AsyncClient';
use AnyEvent;
use Devel::GlobalDestruction;
use Carp;


sub connect {
    my ($class, %opts) = @_;
    my $cv = condvar AnyEvent;
    my $self;

    $class->SUPER::connect(%opts, sub {
        ($self) = @_;
        $cv->send;
    });

    $cv->recv;

    croak $self unless ref $self;
    $self;
}


for my $method (qw(ping insert select update delete call_lua)) {
    no strict 'refs';
    *{ __PACKAGE__ . "::$method" } = sub {
        my ($self, @args) = @_;
        my @res;
        my $cv = condvar AnyEvent;
        my $m = "SUPER::$method";
        $self->$m(@args, sub { @res = @_; $cv->send });
        $cv->recv;

        if ($res[0] ~~ 'ok') {
            return $res[1] // $res[0];
        }
        croak  "$res[1]: $res[2]";
    };
}

sub DESTROY {
    my ($self) = @_;
    return if in_global_destruction;

    my $cv = condvar AnyEvent;
    $self->disconnect(sub { $cv->send });
    $cv->recv;
}

=head1 COPYRIGHT AND LICENSE

 Copyright (C) 2011 Dmitry E. Oboukhov <unera@debian.org>
 Copyright (C) 2011 Roman V. Nikolaev <rshadow@rambler.ru>

 This program is free software, you can redistribute it and/or
 modify it under the terms of the Artistic License.

=head1 VCS

The project is placed git repo on github:
L<https://github.com/unera/dr-tarantool/>.

=cut

1;