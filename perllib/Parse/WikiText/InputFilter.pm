# WikiText parser modules, Copyright (C) 2006 Enno Cramer, Mikhael Goikhman
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the Perl Artistic License or the GNU General
# Public License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

package Parse::WikiText::InputFilter;

use strict;
use warnings;

use IO::Handle;

sub new {
	my $class = shift;
	my $string_or_handle = shift;
	my $is_handle = ref($string_or_handle);

	my $self = {
		handle =>  $is_handle && $string_or_handle,
		string => !$is_handle && $string_or_handle,
		line_n => 0,
		eof    => 0,

		lookahead => undef,
		filter    => [],

		buffer    => undef,

		last_prefix => undef,
		last_match  => undef,
	};

	return bless $self, $class;
}

sub line_n {
	my $self = shift;

	return $self->{line_n};
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
		my $line = $self->readline;

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

sub readline {
	my $self = shift;

	return $self->{lookahead}
		if defined $self->{lookahead} || $self->{eof};

	my $line = $self->{handle}
		? $self->{handle}->getline
		: $self->{string} =~ s/\A(.+\z|.*(?:\r*\n|\r))// ? $1 : undef;

	$self->{eof} = !defined $line;
	$line =~ s/(?:\r*\n|\r)/\n/ if defined $line;

	++$self->{line_n};

	return $self->{lookahead} = $line;
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

	local $_;

	while (
		(defined ($_ = $self->readline) && /^\s*$/)
		|| (defined ($_ = $self->peek) && /^\s*$/)
	) {
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
	$self->{buffer} = undef;
}

1;

__END__
