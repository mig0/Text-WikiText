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

package Parse::WikiText::Latex;

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

# TODO: fix ~ and ^
my %ENTITIES = (
	'{' => '\{',
	'}' => '\}',
	'#' => '\#',
	'_' => '\_',
	'$' => '\$',
	'%' => '\%',
	'&' => '\&',

	'>' => '$>$',
	'<' => '$<$',
	'|' => '$|$',

	'^' => '\verb+^+',
	'~' => '\verb+~+',

	'\\' => '$\backslash$',
);

my $ENTITY_RE = join '|', map { quotemeta } keys %ENTITIES;

sub escape {
	my $text = shift;

	$text =~ s/$ENTITY_RE/$ENTITIES{$&}/ego;

	return $text;
}

# TODO: is it possible to escape these?
my %URL_ENTITIES = (
	'{'  => '',
	'}'  => '',
	'\\' => '',
);

my $URL_ENTITY_RE = join '|', map { quotemeta } keys %URL_ENTITIES;

sub url_escape {
	my $text = shift;

	$text =~ s/$URL_ENTITY_RE/$URL_ENTITIES{$&}/ego;

	return $text;
}

sub fill_in_link {
	my ($self, $chunk) = @_;

	if ($chunk->{style} eq '') {
		# bitmap files
		if ($chunk->{target} =~ /\.(eps|png|jpg|jpeg|gif)$/) {
			$chunk->{style} = '=';

		# network protocols
		} elsif ($chunk->{target} =~ /^(http|ftp|news|mailto|irc):/) {
			$chunk->{style} = '>';

		# common top level domains
		} elsif ($chunk->{target} =~ /^(\w+\.){1,}$RE_TLD(\/|$)/) {
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

		} elsif ($chunk->{target} =~ /^(\w+\.){1,}$RE_TLD(\/|$)/) {
			$chunk->{target} = "http://" . $chunk->{target};
		}

		if ($chunk->{target} =~ /\.$RE_TLD$/) {
			$chunk->{target} .= '/';
		}
	}
}

# TODO: does hyperref support labeled links?
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
			$str .= '\emph{' . escape($chunk->{text}) . '}';

		} elsif ($chunk->{type} eq STRONG) {
			$str .= '\textbf{' . escape($chunk->{text}) . '}';

		} elsif ($chunk->{type} eq UNDERLINE) {
			$str .= '\underbar{' . escape($chunk->{text}) . '}';

		} elsif ($chunk->{type} eq STRIKE) {
			$str .= '\textst{' . escape($chunk->{text}) . '}';

		} elsif ($chunk->{type} eq TYPEWRITER) {
			$str .= '\texttt{' . escape($chunk->{text}) . '}';

		} elsif ($chunk->{type} eq LINK) {
			$self->fill_in_link($chunk);

			if ($chunk->{style} eq '>') {
				if ($chunk->{label} ne $chunk->{target}) {
					$str .= escape($chunk->{label})
						. ' \footnote{' . escape($chunk->{label}) . ': '
						. '\url{' . url_escape($chunk->{target}) . '}'
						. '}';
				} else {
					$str .= '\url{' . url_escape($chunk->{target}) . '}';
				}

			} elsif ($chunk->{style} eq '=') {
				$str .= '\includegraphics{' . $chunk->{target} . '}'

			} elsif ($chunk->{style} eq '#') {
				$str .= '\ref{' . $chunk->{target} . '}~' 
					. escape($chunk->{label});

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

	$text .= "\\paragraph{" . escape($para->{heading}) . "} "
		if defined $para->{heading};

	$text .= $self->dump_text($para->{text}, %opts);

	return $text;
}

sub dump_code {
	my ($self, $code, %opts) = @_;

	return "\\begin{verbatim}\n"
		. $code->{text}
		. "\\end{verbatim}\n";
}

sub dump_preformatted {
	my ($self, $pre, %opts) = @_;

	my $str = $self->dump_text($pre->{text}, %opts);
	$str =~ s/ /\\ /g;

	return "{\\tt\\obeylines $str}\n";
}

sub dump_verbatim {
	my ($self, $verb, %opts) = @_;

	return $verb->{text};
}

sub dump_table {
	my ($self, $table, %opts) = @_;

	my $ncols = 0;
	map { my $c = @{$_->{cols}}; $ncols = $c if $c > $ncols; }
		@{$table->{content}};

	my $str = "\\begin{tabular}{|" . ('l|' x $ncols) . "}\n";
	$str .= "\\hline\n";

	foreach my $row (@{$table->{content}}) {
		my $first = 1;

		foreach my $col (@{$row->{cols}}) {
			$str .= ' & ' unless $first;
			$first = 0;

			$str .= "\\multicolumn{$col->{span}}{|l|}{" if $col->{span};
			$str .= "\\textbf{" if $row->{heading};

			$str .= $self->dump_text($col->{text}, %opts);

			$str .= "}" if $row->{heading};
			$str .= "}" if $col->{span};
		}
		$str .= "\\\\\n";

		$str .= "\\hline\n";
		$str .= "\\hline\n" if $row->{heading};
	}

	$str .= "\\end{tabular}\n";

	return $str;
}

sub dump_rule {
	my ($self, $verb, %opts) = @_;

	return "\\hrule\n";
}

sub dump_quotation {
	my ($self, $quote, %opts) = @_;

	return "\\begin{quote}\n" 
		. $self->dump_list($quote->{content}, %opts) 
		. "\\end{quote}\n"
}

sub dump_listing {
	my ($self, $listing, %opts) = @_;

	return
		"\\begin{itemize}\n" .
		join("", map {
			"\\item[*] " . $self->dump_list($_, %opts)
		} @{$listing->{content}}) .
		"\\end{itemize}\n";
}

sub dump_enumeration {
	my ($self, $enum, %opts) = @_;

	return
		"\\begin{enumerate}\n" .
		join("", map {
			"\\item " . $self->dump_list($_, %opts)
		} @{$enum->{content}}) .
		"\\end{enumerate}\n";
}

sub dump_description {
	my ($self, $descr, %opts) = @_;

	return
		"\\begin{description}\n" .
		join("", map {
			"\\item[$_->[0]] " . $self->dump_list($_->[1], %opts)
		} @{$descr->{content}}) .
		"\\end{description}\n";
}

my @SECTION = qw(
	\chapter
	\section \subsection \subsubsection
	\paragraph \subparagraph
);

sub dump_section {
	my ($self, $heading, %opts) = @_;

	my $level = $heading->{level} + ($opts{heading_offset} || 0);
	my $label = $heading->{heading};

	my $anchor = $label;
	$anchor =~ s/\W/_/g;

	return $SECTION[$level] . "{$label}\n" 
		. "\\label{$anchor}\n\n"
		. $self->dump_list($heading->{content}, %opts);
}

sub dump_list {
	my ($self, $list, %opts) = @_;

	my $str = '';

	my $first = 1;
	foreach my $sect (@$list) {
		$str .= "\n" unless $first;
		$first = 0;

		if ($sect->{type} eq SECTION) {
			$str .= $self->dump_section($sect, %opts);

		} elsif ($sect->{type} eq DESCRIPTION) {
			$str .= $self->dump_description($sect, %opts);

		} elsif ($sect->{type} eq ENUMERATION) {
			$str .= $self->dump_enumeration($sect, %opts);

		} elsif ($sect->{type} eq LISTING) {
			$str .= $self->dump_listing($sect, %opts);

		} elsif ($sect->{type} eq QUOTE) {
			$str .= $self->dump_quotation($sect, %opts);

		} elsif ($sect->{type} eq TABLE) {
			$str .= $self->dump_table($sect, %opts);

		} elsif ($sect->{type} eq RULE) {
			$str .= $self->dump_rule($sect, %opts);

		} elsif ($sect->{type} eq VERBATIM) {
			$str .= $self->dump_verbatim($sect, %opts)
				unless $opts{no_verbatim};

		} elsif ($sect->{type} eq PRE) {
			$str .= $self->dump_preformatted($sect, %opts);

		} elsif ($sect->{type} eq CODE) {
			$str .= $self->dump_code($sect, %opts);

		} elsif ($sect->{type} eq P) {
			$str .= $self->dump_paragraph($sect, %opts);

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

	return $str;
}

sub dump {
	my ($self, $list, %opts) = @_;

	my $str = '';

	if ($opts{full_page}) {
		my $class = escape($opts{class}) || "article";
		my $title = escape($opts{title}) || "No Title";
		my $author = escape($opts{author}) || "Unknown";

		$str .= <<EOF;
\\documentclass{$class}

\\usepackage[utf8]{inputenc}
\\usepackage{soul}
\\usepackage{hyperref}
\\usepackage{url}

\\author{$author}
\\title{$title}

\\begin{document}
\\maketitle
\\tableofcontents
\\newpage

EOF
	}

	$str .= $self->dump_list($list, %opts);

	$str .= "\\end{document}\n"
		if $opts{full_page};

	return $str;
}

1;

__END__
