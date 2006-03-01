# WikiText parser and ouput modules, Copyright (C) 2006 Enno Cramer

package Parse::WikiText::Html;

use strict;

use Parse::WikiText ':types';

my %table = (
    '&' => '&amp;',
    '<' => '&lt;',
    '>' => '&gt;',
    '"' => '&quot;',
);

sub escape {
    my $text = shift;

    $text =~ s/[&<>\"]/$table{$&}/eg;

    return $text;
}

sub dump_text {
    my ($self, $text, %opts) = @_;

    my $str = '';
    foreach my $chunk (@$text) {
        if ($chunk->{type} eq VERBATIM) {
            $str .= $chunk->{text};

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

    my $text = "<p>";

    if (defined $para->{heading}) {
        my $h = $para->{heading};
        $h =~ s,^,<b>,;
        $h =~ s,$,</b>,;
        $h =~ s,\n,<br />\n,;
        $text .= $h;
    }

    $text .= $self->dump_text($para->{text}, %opts);
    $text =~ s/[\r\n]+$//;
    $text .= "</p>";
    
    return $text;
}

sub dump_code {
    my ($self, $code, %opts) = @_;

    my $text .= $code->{text};
    $text =~ s/[\r\n]+$//;

    return "<code><pre>" . $text . "</pre></code>";
}

sub dump_preformatted {
    my ($self, $pre, %opts) = @_;

    my $text .= $pre->{text};
    $text =~ s/[\r\n]+$//;

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
            $str .= escape($col->{text});
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

sub dump_listing {
    my ($self, $listing, %opts) = @_;

    return "<ul>\n"
        . join("", map {
            "<li>" . $self->dump($_, %opts) . "</li>\n"
            } @{$listing->{content}})
        . "</ul>";
}

sub dump_enumeration {
    my ($self, $enum, %opts) = @_;

    return "<ol>\n"
        . join("", map {
            "<li>" . $self->dump($_, %opts) . "</li>\n"
            } @{$enum->{content}})
        . "</ol>";
}

sub dump_description {
    my ($self, $descr, %opts) = @_;

    return "<dl>\n"
        . join("\n", map {
            "<dt>$_->[0]</dt>\n<dd>" . $self->dump($_->[1], %opts) . "</dd>\n"
            } @{$descr->{content}})
        . "</dl>";
}

sub dump_section {
    my ($self, $heading, %opts) = @_;

    my $level = $heading->{level};
    my $label = $heading->{heading};

    my $anchor = $label;
    $anchor =~ s/\s+$//;
    $anchor =~ s/\W/_/g;

    return 
        ($heading->{hidden}
            ? "<a name=\"$anchor\"></a>\n"
            : "<h$level><a name=\"$anchor\">$label</a></h$level>\n")
        . $self->dump($heading->{content}, %opts);
}

sub dump {
    my ($self, $list, %opts) = @_;

    my @list;

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
            push @list, $self->dump_verbatim($sect, %opts);

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

    return join "\n\n", @list;
}

1;

__END__
