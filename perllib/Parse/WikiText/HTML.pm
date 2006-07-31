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

package Parse::WikiText::HTML;

use strict;

use Parse::WikiText ':types';

my $RE_TLD = qr/
	com|edu|gov|int|mil|net|org
	|aero|biz|coop|info|museum|name|pro
	|ac|ad|ae|af|ag|ai|al|am|an|ao|aq|ar|as|at|au|aw|az|ax
	|ba|bb|bd|be|bf|bg|bh|bi|bj|bm|bn|bo|br|bs|bt|bv|bw|by|bz
	|ca|cc|cd|cf|cg|ch|ci|ck|cl|cm|cn|co|cr|cs|cu|cv|cx|cy|cz
	|de|dj|dk|dm|do|dz
	|ec|ee|eg|eh|er|es|et|eu
	|fi|fj|fk|fm|fo|fr
	|ga|gb|gd|ge|gf|gg|gh|gi|gl|gm|gn|gp|gq|gr|gs|gt|gu|gw|gy
	|hk|hm|hn|hr|ht|hu
	|id|ie|il|im|in|io|iq|ir|is|it
	|je|jm|jo|jp
	|ke|kg|kh|ki|km|kn|kp|kr|kw|ky|kz
	|la|lb|lc|li|lk|lr|ls|lt|lu|lv|ly
	|ma|mc|md|mg|mh|mk|ml|mm|mn|mo|mp|mq|mr|ms|mt|mu|mv|mw|mx|my|mz
	|na|nc|ne|nf|ng|ni|nl|no|np|nr|nu|nz
	|om
	|pa|pe|pf|pg|ph|pk|pl|pm|pn|pr|ps|pt|pw|py
	|qa
	|re|ro|ru|rw
	|sa|sb|sc|sd|se|sg|sh|si|sj|sk|sl|sm|sn|so|sr|st|sv|sy|sz
	|tc|td|tf|tg|th|tj|tk|tl|tm|tn|to|tp|tr|tt|tv|tw|tz
	|ua|ug|uk|um|us|uy|uz
	|va|vc|ve|vg|vi|vn|vu
	|wf|ws
	|ye|yt|yu
	|za|zm|zw
/x;


my %ENTITIES = (
	'&' => '&amp;',
	'<' => '&lt;',
	'>' => '&gt;',
	'"' => '&quot;',
);

sub escape {
	my $text = shift;

	$text =~ s/[&<>\"]/$ENTITIES{$&}/eg;

	return $text;
}

sub fill_in_link {
	my ($self, $chunk) = @_;

	if ($chunk->{style} eq '') {
		# bitmap files
		if ($chunk->{target} =~ /\.(png|jpg|jpeg|gif)$/) {
			$chunk->{style} = '=';

			# network protocols
		} elsif ($chunk->{target} =~ /^(http|ftp|news|mailto|irc):/) {
			$chunk->{style} = '>';

			# common top level domains
		} elsif ($chunk->{target} =~ /^(\w+\.){1,}$RE_TLD/) {
			$chunk->{style} = '>';

			# whitespace in urls is bad
		} elsif ($chunk->{target} =~ /\s/) {
			$chunk->{style} = '#';

			# fallback
		} else {
			$chunk->{style} = '>';
		}
	}

	$chunk->{label} ||= $chunk->{target};

	# outside link, without protocol and no directory identifier
	if ($chunk->{style} eq '>'
		&& $chunk->{target} !~ /^\w+:/
		&& $chunk->{target} !~ m,^(/|\.),
	) {
		if ($chunk->{target} =~ /@/) {
			$chunk->{target} = "mailto:" . $chunk->{target};

		} elsif ($chunk->{target} =~ /^www\./) {
			$chunk->{target} = "http://" . $chunk->{target};

		} elsif ($chunk->{target} =~ /^ftp\./) {
			$chunk->{target} = "ftp://" . $chunk->{target};

		} elsif ($chunk->{target} =~ /^(\w+\.){1,}$RE_TLD/) {
			$chunk->{target} = "http://" . $chunk->{target};
		}

		if ($chunk->{target} =~ /\.$RE_TLD$/) {
			$chunk->{target} .= '/';
		}
	}
}

sub dump_text {
	my ($self, $text, %opts) = @_;

	my $str = '';
	foreach my $chunk (@$text) {
		if ($chunk->{type} eq VERBATIM) {
			$str .= $chunk->{text}
				unless $opts{no_verbatim};

		} elsif ($chunk->{type} eq TEXT) {
			$str .= escape($chunk->{text});

		} elsif ($chunk->{type} eq EMPHASIS) {
			$str .= '<em>' . escape($chunk->{text}) . '</em>';

		} elsif ($chunk->{type} eq STRONG) {
			$str .= '<strong>' . escape($chunk->{text}) . '</strong>';

		} elsif ($chunk->{type} eq UNDERLINE) {
			$str .= '<u>' . escape($chunk->{text}) . '</u>';

		} elsif ($chunk->{type} eq STRIKE) {
			$str .= '<strike>' . escape($chunk->{text}) . '</strike>';

		} elsif ($chunk->{type} eq TYPEWRITER) {
			$str .= '<tt>' . escape($chunk->{text}) . '</tt>';

		} elsif ($chunk->{type} eq LINK) {
			$self->fill_in_link($chunk);

			if ($chunk->{style} eq '>') {
				$str .= '<a href="' . $chunk->{target} . '">' 
					. escape($chunk->{label}) 
					. '</a>';

			} elsif ($chunk->{style} eq '=') {
				$str .= '<img src="' . $chunk->{target}
					. '" alt="' . $chunk->{label} . '" />';

			} elsif ($chunk->{style} eq '#') {
				$str .= '<a href="#' . $chunk->{target} . '">' 
					. escape($chunk->{label}) 
					. '</a>';

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

	if (defined $para->{heading}) {
		my $h = $para->{heading};

		$h =~ s,^,<b>,;
		$h =~ s,$,</b>,;
		if (@{$para->{text}}) {
			$h =~ s,\n,<br />\n,;
		} else {
			$h =~ s,\n,,;
		}

		$text .= $h;
	}

	$text .= $self->dump_text($para->{text}, %opts);
	$text =~ s/[\n]+$//;

	$text = "<p>$text</p>"
		unless $opts{no_p};
	
	return $text;
}

sub dump_code {
	my ($self, $code, %opts) = @_;

	my $text .= $code->{text};
	$text =~ s/[\n]+$//;

	return "<pre><code>" . escape($text) . "</code></pre>";
}

sub dump_preformatted {
	my ($self, $pre, %opts) = @_;

	my $text .= $pre->{text};
	$text =~ s/[\n]+$//;

	return "<pre>" . $self->dump_text($pre->{text}) . "</pre>";
}

sub dump_verbatim {
	my ($self, $verb, %opts) = @_;

	return $verb->{text};
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

	$str .= "</table>";

	return $str;
}

sub dump_rule {
	my ($self, $verb, %opts) = @_;

	return "<hr />";
}

sub dump_quotation {
	my ($self, $quote, %opts) = @_;

	return "<blockquote>\n" . $self->dump($quote->{content}, %opts) . "\n</blockquote>"
}

sub _is_simple_p_list (@) {
	foreach (@_) {
		return 0 if @$_ > 1;
		return 0 if $_->[0]->{type} ne P;
		return 0 if defined $_->[0]->{heading};
		return 0 if $_->[0]->{text} =~ /\n/;
	}

	return 1;
}

sub dump_listing {
	my ($self, $listing, %opts) = @_;

	$opts{no_p} = 1 
		if $opts{flat_lists} && _is_simple_p_list(@{$listing->{content}});

	return
		"<ul>\n" .
		join("", map {
			"<li>" . $self->dump($_, %opts) . "</li>\n"
		} @{$listing->{content}}) .
		"</ul>";
}

sub dump_enumeration {
	my ($self, $enum, %opts) = @_;

	$opts{no_p} = 1 
		if $opts{flat_lists} && _is_simple_p_list(@{$enum->{content}});

	return
		"<ol>\n"	.
		join("", map {
			"<li>" . $self->dump($_, %opts) . "</li>\n"
		} @{$enum->{content}}) .
		"</ol>";
}

sub dump_description {
	my ($self, $descr, %opts) = @_;

	$opts{no_p} = 1 
		if $opts{flat_lists} && _is_simple_p_list(map { $_->[1] } @{$descr->{content}});

	return
		"<dl>\n"	.
		join("\n", map {
			"<dt>$_->[0]</dt>\n<dd>" . $self->dump($_->[1], %opts) . "</dd>\n"
		} @{$descr->{content}})	.
		"</dl>";
}

sub dump_section {
	my ($self, $heading, %opts) = @_;

	my $level = $heading->{level} + ($opts{heading_offset} || 0);
	my $label = $heading->{heading};

	my $anchor = $label;
	$anchor =~ s/\s+$//;
	$anchor =~ s/\W/_/g;

	return 
		"<a name=\"$anchor\"></a>\n" .
		($heading->{hidden}	
			? ""
			: "<h$level>$label</h$level>\n")
		. $self->dump($heading->{content}, %opts);
}

sub dump {
	my ($self, $list, %opts) = @_;

	my @list;

	if (caller ne __PACKAGE__ && $opts{full_page}) {
		my $title = $opts{title} || "";
		push @list, <<EOF;
<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.0 Strict//EN' "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
<head>
  <title>$title</title>
</head>
<body>
EOF
	}

	foreach my $sect (@$list) {
		if ($sect->{type} eq SECTION) {
			push @list, $self->dump_section($sect, %opts);

		} elsif ($sect->{type} eq DESCRIPTION) {
			push @list, $self->dump_description($sect, %opts);

		} elsif ($sect->{type} eq ENUMERATION) {
			push @list, $self->dump_enumeration($sect, %opts);

		} elsif ($sect->{type} eq LISTING) {
			push @list, $self->dump_listing($sect, %opts);

		} elsif ($sect->{type} eq QUOTE) {
			push @list, $self->dump_quotation($sect, %opts);

		} elsif ($sect->{type} eq TABLE) {
			push @list, $self->dump_table($sect, %opts);

		} elsif ($sect->{type} eq RULE) {
			push @list, $self->dump_rule($sect, %opts);

		} elsif ($sect->{type} eq VERBATIM) {
			push @list, $self->dump_verbatim($sect, %opts)
				unless $opts{no_verbatim};

		} elsif ($sect->{type} eq PRE) {
			push @list, $self->dump_preformatted($sect, %opts);

		} elsif ($sect->{type} eq CODE) {
			push @list, $self->dump_code($sect, %opts);

		} elsif ($sect->{type} eq P) {
			push @list, $self->dump_paragraph($sect, %opts);

		} elsif ($sect->{type} eq COMMENT) {
			# nada

		} else {
			warn(
				 "Unrecognized block type '"
				 . $sect->{type} . "' defined on line "
				 . $sect->{line} . ".\n"
			);
		}
	}

	push @list, "</body>\n</html>"
		if caller ne __PACKAGE__ && $opts{full_page};

	my $str = join("\n\n", @list);
	$str .= "\n" if (caller ne __PACKAGE__);

	return $str;
}

1;

__END__
