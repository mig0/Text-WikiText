# WikiText parser modules, Copyright (C) 2006-7 Enno Cramer, Mikhael Goikhman
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

package Parse::WikiText::Output::Pod;

use strict;
use warnings;

use base 'Parse::WikiText::Output';

use Parse::WikiText ':types';

sub entities {
	'<' => 'E<lt>',
	'>' => 'E<gt>',
}

sub dump_text {
	my ($self, $text, %opts) = @_;

	my $str = '';
	foreach my $chunk (@$text) {
		if ($chunk->{type} eq VERBATIM) {
			$str .= $chunk->{text}
				unless $opts{no_verbatim};

		} elsif ($chunk->{type} eq TEXT) {
			$str .= $self->escape($chunk->{text});

		} elsif ($chunk->{type} eq EMPHASIS) {
			$str .= 'I<' . $self->escape($chunk->{text}) . '>';

		} elsif ($chunk->{type} eq STRONG) {
			$str .= 'B<' . $self->escape($chunk->{text}) . '>';

		} elsif ($chunk->{type} eq UNDERLINE) {
			$str .= '"' . $self->escape($chunk->{text}) . '"';

		} elsif ($chunk->{type} eq STRIKE) {
			$str .= '"' . $self->escape($chunk->{text}) . '"';

		} elsif ($chunk->{type} eq TYPEWRITER) {
			$str .= 'C<' . $self->escape($chunk->{text}) . '>';

		} elsif ($chunk->{type} eq LINK) {
			$self->fill_in_link($chunk);

			if ($chunk->{style} eq '>') {
				$str .= 'L<' . $chunk->{target} . '|'
					. $self->escape($chunk->{label}) . '>';

			} elsif ($chunk->{style} eq '=') {
				$str .= "[image: $chunk->{target}; $chunk->{label}]";

			} elsif ($chunk->{style} eq '#') {
				$str .= "[cross: $chunk->{target}; $chunk->{label}]";

			} else {
				warn("Unrecognized link style '" . $chunk->{style} . "'.\n");
			}

		} else {
			warn("Unrecognized text markup '" . $chunk->{type} . "'.\n");
		}
	}

	return $str;
}

sub dump_paragraph {
	my ($self, $para, %opts) = @_;

	my $str = "";

	$str .= "B<" . $self->escape($para->{heading}) . "> "
		if $para->{heading};
	$str .= $self->dump_text($para->{text}, %opts);

	return $str;
}

sub dump_code {
	my ($self, $code, %opts) = @_;

	return "C<" . $self->escape($code->{text}) . ">\n";
}

sub dump_preformatted {
	my ($self, $pre, %opts) = @_;

	$self->add_indentation_block($pre->{text}, %opts);
}

sub dump_table {
	my ($self, $table, %opts) = @_;

	$self->add_indentation_block($self->dump_ascii_formatted_table($table, %opts), %opts);
}

sub dump_rule {
	my ($self, $rule, %opts) = @_;

	return "\n";
}

sub dump_quotation {
	my ($self, $quote, %opts) = @_;

	$self->add_indentation_block($self->dump_list($quote->{content}, %opts), %opts);
}

sub dump_listing {
	my ($self, $listing, %opts) = @_;

	return
		"\n" .
		join("", map {
			"=item\n\n" . $self->dump_list($_, %opts) . "\n"
		} @{$listing->{content}});
}

sub dump_enumeration {
	my ($self, $enum, %opts) = @_;

	$self->dump_listing($enum, %opts);
}

sub dump_description {
	my ($self, $descr, %opts) = @_;

	return
		"\n" .
		join("", map {
			"=item$_->[0]\n\n" . $self->dump_list($_->[1], %opts) . "\n"
		} @{$descr->{content}});
}

sub dump_section {
	my ($self, $heading, %opts) = @_;

	my $level = $heading->{level} + ($opts{heading_offset} || 0);
	my $label = $self->escape($heading->{heading});

	return
		"\n=head$level $label\n\n"
		. $self->dump_list($heading->{content}, %opts);
}

sub construct_full_page {
	my ($self, $page, %opts) = @_;

	$page = "=head1 DESCRIPTION\n\n$page" unless $page =~ /^=/;

	my $name = $self->escape($opts{name} || "Unknown");

	return <<EOS;
=head1 NAME

$name - $opts{escaped_title}

$page
=head1 AUTHORS

$opts{escaped_author}

=cut
EOS
}

1;

__END__
