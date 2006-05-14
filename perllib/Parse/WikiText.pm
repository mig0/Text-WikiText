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

package Parse::WikiText;

use strict;
use warnings;

our $VERSION = 0.1;

use constant {
	COMMENT     => 'comment',
	VERBATIM    => 'verbatim',

	SECTION     => 'section',

	QUOTE       => 'quotation',
	LISTING     => 'listing',
	ENUMERATION => 'enumeration',
	DESCRIPTION => 'description',

	TABLE       => 'table',
	RULE        => 'horizontal-rule',
	P           => 'paragraph',
	PRE         => 'preformatted',
	CODE        => 'code',

	EMPHASIS    => 'emphasis',
	STRONG      => 'strong',
	UNDERLINE   => 'underline',
	STRIKE      => 'strike',
	TYPEWRITER  => 'typewriter',
	LINK        => 'link',

	TEXT        => 'normal text',
};

use base 'Exporter';

our @EXPORT = qw();
our @EXPORT_OK = qw(
	COMMENT VERBATIM
	SECTION QUOTE LISTING ENUMERATION DESCRIPTION
	TABLE RULE P PRE CODE
	EMPHASIS STRONG UNDERLINE STRIKE TYPEWRITER LINK
	TEXT
);
our %EXPORT_TAGS = (
	generic     => [qw(COMMENT VERBATIM)],
	environment => [qw(SECTION QUOTE LISTING ENUMERATION DESCRIPTION)],
	paragraphs  => [qw(TABLE RULE P PRE CODE)],
	inline      => [qw(EMPHASIS STRONG UNDERLINE STRIKE TYPEWRITER LINK TEXT)],
	types       => [qw(
		COMMENT VERBATIM
		SECTION QUOTE LISTING ENUMERATION DESCRIPTION
		TABLE RULE P PRE CODE
		EMPHASIS STRONG UNDERLINE STRIKE TYPEWRITER LINK
		TEXT
	)],
);

my $RE_INLINE_PRE = qr/[\s(]/;
my $RE_INLINE_POST = qr/[\s).!?,:;]|$/;

my %DEFAULT_INLINE_RE = (
	EMPHASIS() => {
		open   => qr/\//,
		close  => qr/\//,
	},

	STRONG() => {
		open   => qr/\*/,
		close  => qr/\*/,
	},

	UNDERLINE() => {
		open   => qr/_/,
		close  => qr/_/,
	},

	STRIKE() => {
		open   => qr/-/,
		close  => qr/-/,
	},

	TYPEWRITER() => {
		open   => qr/{/,
		close  => qr/}/,
	},

	VERBATIM() => {
		open   => qr/{{/,
		close  => qr/}}/,
	},

	LINK() => {
		open   => qr/\[[>=\#]?/,
		close  => qr/\]/,
		code   => sub {
			my ($self, $type, $text, $match) = @_;

			(my $style = $match) =~ s/^\[//;
			my ($target, $label) = split /\|/, $text, 2;

			return {
				type   => LINK,
				label  => $label,
				target => $target,
				style  => $style,
			};
		},
	},
);

my %DEFAULT_PARA_RE = (
	P() => {
		open   => qr/(?:.+?::\s)?/,
		close  => undef,
		code   => sub {
			my ($self, $type, $text, $match) = @_;
			$match =~ s/:://;

			my $p = {
				type => P,
				text => $self->parse_paragraph($text)
			};

			$p->{heading} = $match
				if $match;

			return $p;
		},
	},

	PRE() => {
		open   => qr/{\s/,
		close  => qr/(?:^|\s)}/,
		code   => sub {
			my ($self, $type, $text) = @_;
			return { type => PRE, text => $self->parse_paragraph($text) };
		},
	},

	CODE() => {
		open   => qr/[!|]\s/,
		close  => undef,
		filter => qr/[!|]($|\s)/,
	},

	VERBATIM() => {
		open   => qr/{{\s/,
		close  => qr/(?:^|\s)}}/,
	},

	RULE() => {
		open   => qr/-{3,}\n/,
		close  => qr//,
		code   => sub {
			return { type => RULE };
		},
	},

	# TODO: fix column span vs empty cells
	TABLE() => {
		open   => qr/\+[+-]*\+\n$/,
		close  => undef,
		code   => sub {
			my ($self, $type, $text) = @_;

			my @rows = split /\n/, $text;
			my $content = [];
			for (my $i = 0; $i < @rows; ++$i) {
				next if $rows[$i] =~ /^\+(?:-*\+)*$/;

				my $row = { cols => [] };

				$row->{heading} = 1
					if ($i < @rows - 2) && ($rows[$i+1] =~ /^[+-]+$/);

				$rows[$i] =~ s/^\|\s*|\s*\|$//g;

				my $span = 1;
				foreach my $col (split /\s*\|\s*/, $rows[$i]) {
					if ($col eq '') {
						++$span;

					} else {
						my $column = { text => $col };
						$column->{span} = $span if $span > 1;
						push @{$row->{cols}}, $column;

						$span = 1;
					}
				}

				push @$content, $row;
			}

			return { type => TABLE, content => $content };
		},
	},
);

my %DEFAULT_ENVIRONMENT_RE = (
	QUOTE() => {
		open   => qr/>\s/,
		close  => undef,
		filter => qr/[> ]($|\s)/,
	},

	LISTING() => {
		open   => qr/[*o-]\s/,
		close  => undef,
		merge  => 1,
	},

	ENUMERATION() => {
		open   => qr/(?:\d+[.)]|\#)\s/,
		close  => undef,
		merge  => 1,
	},

	DESCRIPTION() => {
		open   => qr/:.+?:\s/,
		close  => undef,
		merge  => 1,
		code   => sub {
			my ($self, $type, $content, $match) = @_;
			$match =~ s/^:|:\s$//g;
			return [ $match, $content ];
		},
	},
);

my %DEFAULT_SECTION_RE = (
	open   => qr/=+\[?\s/,
	close  => qr/(?:^|\s)\]?=+|^$/,
	code   => sub {
		my ($self, $type, $heading, $content, $match) = @_;

		$heading =~ s/[\r\n]//g;

		return {
			type	=> SECTION,
			level   => scalar $match =~ tr/=//,
			hidden  => scalar $match =~ /\[/,
			heading => $heading,
			content => $content,
		};
	}
);

use Parse::WikiText::InputFilter;

sub new {
	my $class = shift;

	my $self = {
	};

	return bless $self, $class;
}

sub parse_paragraph {
	my ($self, $text) = @_;

	my @list;

	while (length $text) {
		my $elem = undef;

		foreach my $type (keys %DEFAULT_INLINE_RE) {
			my $def = $DEFAULT_INLINE_RE{$type};

			if ($text =~ s/
				^($def->{open})       # opening markup
				(\S|\S.*?\S)          # content (no leading or trailing ws)
				($def->{close})       # closing markup
				(?=$RE_INLINE_POST)   # followed by sentence char or ws
			//xs) {
				$elem = exists $def->{code}
					? $def->{code}->($self, $type, $2, $1, $3)
					: { type => $type, text => $2 };
				last;
			}
		}

		if (! defined $elem) {
			if ($text =~ s/^(.*?($RE_INLINE_PRE)+)//s) {
				$elem = { type => TEXT, text => $& };
			} else {
				$elem = { type => TEXT, text => $text };
				$text = '';
			}
		}

		if (@list && $list[-1]->{type} eq TEXT && $elem->{type} eq TEXT) {
			$list[-1]->{text} .= $elem->{text};
		} else {
			push @list, $elem;
		}
	}

	return \@list;
}

sub parse_parlike {
	my ($self, $input, $filter, $close, $parbreak) = @_;

	my $para = '';
	my $first = 1;
	my $last;

	$input->push_filter($filter || qr//);

	local $_;

	while (defined ($_ = $input->peek)) {
		last if !defined $close && defined $parbreak && /^$parbreak/;

		$last = defined $close
			? s/$close\n?$//
			: !$first && !defined $filter && s/^\n?$//;

		$para .= $_;
		$input->commit;

		$first = 0;

		last if $last;
	}

	$input->pop_filter;

	warn("Missing block terminator on input line " . $input->line_n . ".\n")
		if defined $close && !$last;

	return $para;
}

sub parse_atom {
	my ($self, $input, $parbreak) = @_;

	my $line_n = $input->line_n;
	my $atom = undef;

	# (foo) specials (end)
	if ($input->match(qr/\((begin +)?[\w -]+\)\n/)) {
		my $match = $input->last_match;
		$match =~ s/^\((begin +)?| *\)\n//g;

		my @modifiers = split / +/, $match;
		my $type = pop @modifiers;

		my $text =
			$self->parse_parlike($input, undef, qr/\(end( +\Q$type\E)?\)/);

		$atom = exists $DEFAULT_PARA_RE{$type} && exists $DEFAULT_PARA_RE{$type}{code}
			? $DEFAULT_PARA_RE{$type}->{code}->($self, $type, $text, $match, [ @modifiers ])
			: { type => $type, modifiers => [ @modifiers ], text => $text };

	} else {
		foreach my $type (keys %DEFAULT_PARA_RE) {
			my $def = $DEFAULT_PARA_RE{$type};

			if ($input->match($def->{open})) {
				my $match = $input->last_match;
				my $text = $self->parse_parlike(
					$input, $def->{filter}, $def->{close}, $parbreak
				);

				$atom = exists $def->{code}
					? $def->{code}->($self, $type, $text, $match)
					: { type => $type, text => $text };
				last;
			}
		}
	}

	if (defined $atom) {
		$atom->{line_n} = $line_n;
		$input->flush_empty;
	}

	return $atom;
}


my $RE_ALL_ENV =
	eval "qr/" . (join "|", map { $_->{open} } values %DEFAULT_ENVIRONMENT_RE) . "|" . $DEFAULT_SECTION_RE{open} . "/";

sub parse_block_list {
	my ($self, $input, $filter, $close, $parbreak) = @_;

	my  @list = ();
	my $last;

	local $_;

	while (defined ($_ = $input->peek)) {
		last if !defined $filter && /^$RE_ALL_ENV/;
		$last = defined $close && s/$close\n?$//;

		push @list, $self->parse_block($input, $parbreak);

		last if $last;
	}

	return \@list;
}

sub parse_block {
	my ($self, $input, $parbreak) = @_;

	my $block = undef;

	foreach my $type (keys %DEFAULT_ENVIRONMENT_RE) {
		my $def = $DEFAULT_ENVIRONMENT_RE{$type};

		if ($input->match($def->{open})) {
			$input->push_filter($def->{filter} || qr//);

			if ($def->{merge}) {
				my $elements = [];

				do {
					my $match = $input->last_match;

					if ($input->peek =~ /^\s*$/) {
						$input->commit;
						$input->flush_empty;
					}

					my $content = $self->parse_block_list(
						$input, $def->{filter}, $def->{close}, $def->{open}
					);

					my $elem = exists $def->{code}
						? $def->{code}->($self, $type, $content, $match)
						: $content;

					push @$elements, $elem;
				} while ($input->match(qr/^$def->{open}/));

				$block = exists $def->{merge_code}
					? $def->{merge_code}->($self, $type, $elements)
					: { type => $type, content => $elements };

			} else {
				my $match = $input->last_match;

				if ($input->peek =~ /^\s*$/) {
					$input->commit;
					$input->flush_empty;
				}

				my $content = $self->parse_block_list(
					$input, $def->{filter}, $def->{close}
				);

				$block = exists $def->{code}
					? $def->{code}->($self, $type, $content, $match)
					: { type => $type, content => $content };
			}

			$input->pop_filter;
			$input->flush_empty;

			last;
		}
	}

	if (! defined $block) {
		$block = $self->parse_atom($input, $parbreak);
	}

	return $block;
}

sub parse_struct_list {
	my ($self, $input) = @_;

	my  @list = ();
	my $last;

	local $_;

	while (defined ($_ = $input->peek)) {
		last if /^$DEFAULT_SECTION_RE{open}/;

		push @list, $self->parse_structure($input);

		last if $last;
	}

	return \@list;
}

sub parse_structure {
	my ($self, $input) = @_;

	my $struct = undef;

	# = heading
	if ($input->match($DEFAULT_SECTION_RE{open})) {
		my $match = $input->last_match;
		my $heading =
			$self->parse_parlike($input, undef, $DEFAULT_SECTION_RE{close});

		$input->flush_empty;

		my $content =
			$self->parse_struct_list($input);

		$struct = exists $DEFAULT_SECTION_RE{code}
			? $DEFAULT_SECTION_RE{code}->($self, SECTION, $heading, $content, $match)
			: { type => SECTION, heading => $heading, content => $content };

	} else {
		$struct = $self->parse_block($input);
	}

	return $struct;
}

sub parse {
	my ($self, $string_or_stream) = @_;

	my $input = Parse::WikiText::InputFilter->new($string_or_stream);

	my @list;
	while (defined $input->peek) {
		push @list, $self->parse_structure($input);
	}

	return \@list;
}

sub convert {
	my ($self, $string_or_stream, %opts) = @_;

	my $output_class = !$opts{format} || $opts{format} =~ /html/i
		? 'Parse::WikiText::HTML'
		: die "WikiText: Unknown output format ($opts{format})\n";

	eval "use $output_class";

	my $parsed_structures = $self->parse($string_or_stream);
	$output_class->dump($parsed_structures, %opts);
}

1;

__END__
