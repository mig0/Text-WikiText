use strict;

package Parse::WikiText::InputFilter;

use IO::Handle;

sub new {
    my $class = shift;
    my $handle = shift;

    my $self = {
        handle => $handle,
        line   => 0,

        lookahead => undef,
        filter    => [],

        buffer    => undef,

        last_prefix => undef,
        last_match  => undef,
    };

    return bless $self, $class;
}

sub line {
    my $self = shift;

    return $self->{line};
}

sub last_prefix {
    my $self = shift;

    return $self->{last_prefix};
}

sub last_match {
    my $self = shift;

    return $self->{last_match};
}

sub peek {
    my $self = shift;

    if (! defined $self->{buffer}) {
        my $line = $self->read;

        if (defined $line) {
            foreach my $filter (@{$self->{filter}}) {
                if ($line !~ s/^$filter//) {
                    $line = undef;
                    last;
                }
            }
        }

        $self->{buffer} = $line;
    }

    return $self->{buffer};
}

sub read {
    my $self = shift;

    return $self->{lookahead}
        if defined $self->{lookahead};

    $self->{lookahead} = $self->{handle}->getline;
    ++$self->{line};

    return $self->{lookahead};
}

sub try {
    my ($self, $arg) = @_;

    $self->peek;
    my $ret = defined $self->{buffer} && $self->{buffer} =~ /^(\s*)($arg)/;

    $self->{last_prefix} = $1;
    $self->{last_match} = $2;

    return $ret;
}

sub match {
    my ($self, $arg) = @_;

    $self->peek;
    my $ret = defined $self->{buffer} && $self->{buffer} =~ s/^(\s*)($arg)//;

    $self->{last_prefix} = $1;
    $self->{last_match} = $2;

    return $ret;
}

sub commit {
    my $self = shift;

    $self->{buffer} = undef;
    $self->{lookahead} = undef;
}

sub flush_empty {
    my $self = shift;

    while (defined ($_ = $self->read) && $_ =~ /^\s*$/) {
        $self->commit;
    }
}

sub push_filter {
    my ($self, $filter) = @_;

    push @{$self->{filter}}, defined $self->{last_prefix}
      ? qr/\Q$self->{last_prefix}\E$filter/
      : $filter;
}

sub pop_filter {
    my $self = shift;

    pop @{$self->{filter}};
}

1;

__END__
