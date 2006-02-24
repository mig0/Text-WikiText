use strict;

package Parse::WikiText::Html;

use Parse::WikiText ':types';

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

    $text .= $para->{text};
    $text =~ s/[\r\n]+$//;
    $text .= "</p>\n";
    
    return $text;
}

sub dump_code {
    my ($self, $code, %opts) = @_;

    my $text .= $code->{text};
    $text =~ s/[\r\n]+$//;

    return "<code><pre>" . $text . "</pre></code>\n";
}

sub dump_preformatted {
    my ($self, $pre, %opts) = @_;

    my $text .= $pre->{text};
    $text =~ s/[\r\n]+$//;

    return "<pre>" . $text . "</pre>\n";
}

sub dump_verbatim {
    my ($self, $verb, %opts) = @_;

    return $verb->{text};
}

sub dump_rule {
    my ($self, $verb, %opts) = @_;

    return "<hr />\n";
}

sub dump_quotation {
    my ($self, $quote, %opts) = @_;

    return "<quote>\n" . $self->dump($quote->{content}, %opts) . "</quote>\n"
}

sub dump_listing {
    my ($self, $listing, %opts) = @_;

    return "<ul>\n" . join("", map { "<li>" . $self->dump($_, %opts) . "</li>" } @{$listing->{items}}) . "</ul>\n";
}

sub dump_enumeration {
    my ($self, $enum, %opts) = @_;

    return "<ol>\n" . join("", map { "<li>" . $self->dump($_, %opts) . "</li>" } @{$enum->{items}}) . "</ol>\n";
}

sub dump_description {
    my ($self, $descr, %opts) = @_;

    return "<dl>\n" . join("", map { "<dt>$_->[0]</dt><dd>" . $self->dump($_->[1], %opts) . "</dd>" } @{$descr->{items}}) . "</dl>\n";
}

sub dump_heading {
    my ($self, $heading, %opts) = @_;

    my $level = $heading->{level};
    my $label = $heading->{text};

    my $anchor = $label;
    $anchor =~ s/\s+$//;
    $anchor =~ s/ /_/;

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
        if ($sect->{type} eq H) {
            push @list, $self->dump_heading($sect, %opts);

        } elsif ($sect->{type} eq DL) {
            push @list, $self->dump_description($sect, %opts);

        } elsif ($sect->{type} eq OL) {
            push @list, $self->dump_enumeration($sect, %opts);

        } elsif ($sect->{type} eq UL) {
            push @list, $self->dump_listing($sect, %opts);

        } elsif ($sect->{type} eq QUOTE) {
            push @list, $self->dump_quotation($sect, %opts);

        } elsif ($sect->{type} eq HR) {
            push @list, $self->dump_rule($sect, %opts);

        } elsif ($sect->{type} eq VERB) {
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

    return join "\n", @list;
}

1;

__END__
