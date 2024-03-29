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

package Text::WikiText::Output::HTML;

use strict;
use warnings;

use base 'Text::WikiText::Output';

use Text::WikiText ':types';

sub entities {
	'&' => '&amp;',
	'<' => '&lt;',
	'>' => '&gt;',
	'"' => '&quot;',
}

sub _label_to_anchor ($) {
	my $anchor = shift;

	$anchor =~ s/\s+$//;
	$anchor =~ s/\W/_/g;

	return $anchor;
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
			$str .= '<em>' . $self->escape($chunk->{text}) . '</em>';

		} elsif ($chunk->{type} eq STRONG) {
			$str .= '<strong>' . $self->escape($chunk->{text}) . '</strong>';

		} elsif ($chunk->{type} eq UNDERLINE) {
			$str .= '<u>' . $self->escape($chunk->{text}) . '</u>';

		} elsif ($chunk->{type} eq STRIKE) {
			if ($opts{use_css}) {
				$str .= '<span class="strike">'
					. $self->escape($chunk->{text})
					. '</span>';
			} else {
				$str .= '<strike>'
					. $self->escape($chunk->{text})
					. '</strike>';
			}

		} elsif ($chunk->{type} eq TYPEWRITER) {
			$str .= '<tt>' . $self->escape($chunk->{text}) . '</tt>';

		} elsif ($chunk->{type} eq LINK) {
			$self->fill_in_link($chunk);

			my $target = $self->escape($chunk->{target});
			my $label = $self->escape($chunk->{label});

			if ($chunk->{style} eq '>') {
				$str .= qq(<a href="$target">$label</a>);

			} elsif ($chunk->{style} eq '=') {
				$str .= qq(<img src="$target" alt="$label" />);

			} elsif ($chunk->{style} eq '#') {
				my $anchor = _label_to_anchor($chunk->{target});

				$str .= qq(<a href="#$anchor">$label</a>);

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

	my $text = '';

	$text .= "<p>" unless $opts{no_p};

	if (defined $para->{heading}) {
		if ($opts{use_css}) {
			$text .= '<span class="paragraph">'
				. $self->escape($para->{heading})
				. '</span> ';
		} else {
			$text .= '<b>'
				. $self->escape($para->{heading})
				. '</b>&nbsp;&nbsp;&nbsp;';
		}
	}

	$text .= $self->dump_text($para->{text}, %opts);
	$text =~ s,\n$,</p>\n, unless $opts{no_p};
	
	return $text;
}

sub dump_code {
	my ($self, $code, %opts) = @_;

	my $text = "<pre><code>"
		. $self->escape($code->{text});
	$text =~ s,\n$,</code></pre>\n,;

	return $text;
}

sub dump_preformatted {
	my ($self, $pre, %opts) = @_;

	my $text = "<pre>"
		. $self->dump_text($pre->{text});
	$text =~ s,\n$,</pre>\n,;

	return $text;
}

sub dump_table {
	my ($self, $table, %opts) = @_;

	my $str = "<table>\n";

	foreach my $row (@{$table->{content}}) {
		$str .= "<tr>";

		my $tag = $row->{heading} ? "th" : "td";
		foreach my $col (@{$row->{cols}}) {
			$str .= "<$tag";
			$str .= " colspan=\"$col->{span}\"" if $col->{span};
			$str .= ">";
			$str .= $self->dump_text($col->{text}, %opts);
			$str .= "</$tag>";
		}

		$str .= "</tr>\n";
	}

	$str .= "</table>\n";

	return $str;
}

sub dump_rule {
	my ($self, $rule, %opts) = @_;

	return "<hr />\n";
}

sub dump_quotation {
	my ($self, $quote, %opts) = @_;

	return "<blockquote>\n" 
		. $self->dump_list($quote->{content}, %opts) 
		. "</blockquote>\n"
}

sub _is_simple_p {
 	my $elem = shift;

	if ($elem->{type} eq P) {
		return 0 if defined $elem->{heading};
		return 0 if $elem->{text} =~ /\n/;

		return 1;

	} else {
		return 0;
	}
}

sub _is_simple_p_list {
	my $list = shift;

	if ($list->{type} eq LISTING || $list->{type} eq ENUMERATION) {
		foreach (@{$list->{content}}) {
			return 0 if @$_ > 0 && !_is_simple_p($_->[0]);
			return 0 if @$_ > 1 && !_is_simple_p_list($_->[1]);
			return 0 if @$_ > 2;
		}

		return 1;

	} else {
		return 0;
	}
}

sub _is_simple_p_description {
	my $list = shift;

	if ($list->{type} eq DESCRIPTION) {
		foreach (map { $_->[1] } @{$list->{content}}) {
			return 0 if @$_ > 0 && !_is_simple_p($_->[0]);
			return 0 if @$_ > 1;
		}

		return 1;

	} else {
		return 0;
	}
}

sub dump_listing {
	my ($self, $listing, %opts) = @_;

	$opts{no_p} ||= $opts{flat_lists} && _is_simple_p_list($listing);

	return
		"<ul>\n" .
		join("", map {
			"<li>\n" . $self->dump_list($_, %opts) . "</li>\n"
		} @{$listing->{content}}) .
		"</ul>\n";
}

sub dump_enumeration {
	my ($self, $enum, %opts) = @_;

	$opts{no_p} ||= $opts{flat_lists} && _is_simple_p_list($enum);

	return
		"<ol>\n" .
		join("", map {
			"<li>\n" . $self->dump_list($_, %opts) . "</li>\n"
		} @{$enum->{content}}) .
		"</ol>\n";
}

sub dump_description {
	my ($self, $descr, %opts) = @_;

	$opts{no_p} ||= $opts{flat_lists} && _is_simple_p_description($descr);

	return
		"<dl>\n" .
		join("\n", map {
			"<dt>$_->[0]</dt>\n<dd>\n" 
				. $self->dump_list($_->[1], %opts)
				. "</dd>\n"
		} @{$descr->{content}}) .
		"</dl>\n";
}

sub dump_section {
	my ($self, $heading, %opts) = @_;

	my $level = $heading->{level} + ($opts{heading_offset} || 0);
	my $label = $heading->{heading};

	my $anchor = _label_to_anchor($label);

	return 
		"<a name=\"$anchor\"></a>\n"
		. "<h$level>$label</h$level>\n\n"
		. $self->dump_list($heading->{content}, %opts);
}

sub construct_full_page {
	my ($self, $page, %opts) = @_;

	my $css = '';
	if ($opts{use_css}) {
		$css = <<EOS;
  <style type="text/css"><!--
      span.strike { text-decoration: line-through; }
      span.paragraph { margin-right: 1em; font-weight: bold; }
  --></style>
EOS
	}

	return <<EOS;
<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.0 Strict//EN' "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
<head>
  <title>$opts{escaped_title}</title>
  <meta name="author" content="$opts{escaped_author}" />
$css
</head>
<body>

$page
</body>
</html>
EOS
}

1;

__END__
