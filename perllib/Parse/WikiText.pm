use strict;

# TODO: early paragraph termination (req no empty line between items of lists)
# TODO: paragraph parser (inline markup)
# TODO: invisible headings (=+\[)
# TODO: single line heading?

package Parse::WikiText;

use vars qw($VERSION @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION = 0.1;

use constant {
    P        => 'paragraph',
    PRE      => 'preformatted',
    CODE     => 'code',
    VERB     => 'verbatim',
    HR       => 'horizontal rule',
    QUOTE    => 'quotation',
    UL       => 'listing',
    OL       => 'enumeration',
    DL       => 'description',
    H        => 'heading',
    COMMENT  => 'comment',
};

use Exporter 'import';

@EXPORT = qw();
@EXPORT_OK = qw(P PRE CODE VERB HR QUOTE UL OL DL H COMMENT);
%EXPORT_TAGS = (
    types => [qw(P PRE CODE VERB HR QUOTE UL OL DL H COMMENT)],
);


my %RE = (
    p => {
        open   => qr/(.+?::\n?)?/,
        close  => undef,
        filter => undef,
    },

    pre => {
        open   => qr/{\s/,
        close  => qr/(^|\s)}/,
        filter => undef,
    },

    code => {
        open   => qr/\|\s/,
        close  => undef,
        filter => qr/\|\s/,
    },

    verb => {
        open   => qr/{{\s/,
        close  => qr/(^|\s)}}/,
        filter => undef,
    },

    hr => {
        open   => qr/-{3,}\n/,
        close  => undef,
        filter => undef,
    },

    special => {
        open   => qr/\([a-zA-Z0-9 _-]+\)\n/,
        close  => qr/\(end\)/,
        filter => undef,
    },

    quote => {
        open   => qr/>\s/,
        close  => undef,
        filter => qr/>\s/,
    },

    ul => {
        open   => qr/[*o-]\s/,
        close  => undef,
        filter => undef,
    },

    ol => {
        open   => qr/(\d+[.)]|\#)\s/,
        close  => undef,
        filter => undef,
    },

    dl => {
        open   => qr/:.+?:\s/,
        close  => undef,
        filter => undef,
    },

    h => {
        open   => qr/=+\[?\s/,
        close  => qr/(^|\s)\]?=+|^\n$/,
        filter => undef,
    },
);

my $RE_ALL_ENV =
    qr/$RE{quote}{open}|$RE{ul}{open}|$RE{ol}{open}|$RE{dl}{open}|$RE{h}{open}/;

use Parse::WikiText::InputFilter;

sub new {
    my $class = shift;
    my $stream = shift;

    my $self = {
    };

    return bless $self, $class;
}

sub parse_parlike {
    my ($self, $input, $filter, $break) = @_;

    my $para = '';
    my $last;

    $input->push_filter($filter || qr//);

    while (defined ($_ = $input->peek)) {
        $last = defined $break
            ? s/$break\n?$//
            : s/^\n//;

        $para .= $_;
        $input->commit;

        last if $last;
    }

    $input->pop_filter;

    warn("Missing block terminator on input line " . $input->line . ".\n")
        if defined $break && !$last;

    return $para;
}

sub parse_atom {
    my ($self, $input) = @_;

    my $atom = { line => $input->line };

    # (foo) specials (end)
    if ($input->match($RE{special}{open})) {
        (my $type = $input->last_match) =~ s/^\(\s*(begin )?|\s*\)\s*$//g;

        $atom->{type} = $type;
        $atom->{text} =
            $self->parse_parlike($input, $RE{special}{filter}, $RE{special}{close});

    # --- hr
    } elsif ($input->match($RE{hr}{open})) {
        $atom->{type} = HR;
        $input->commit;

    # {{ verbatim }}
    } elsif ($input->match($RE{verb}{open})) {
        $atom->{type} = VERB;
        $atom->{text} =
            $self->parse_parlike($input, $RE{verb}{filter}, $RE{verb}{close});

    # { pre }
    } elsif ($input->match($RE{pre}{open})) {
        $atom->{type} = PRE;
        $atom->{text} =
            $self->parse_parlike($input, $RE{pre}{filter}, $RE{pre}{close});

    # | code
    } elsif ($input->match($RE{code}{open})) {
        $atom->{type} = CODE;
        $atom->{text} =
            $self->parse_parlike($input, $RE{code}{filter}, $RE{code}{close});

    # paragraph
    } elsif ($input->match($RE{p}{open})) {
        (my $heading = $input->last_match) =~ s/:://;

        $atom->{type} = P;
        $atom->{heading} = $heading unless $heading =~ /^\s*$/;
        $atom->{text} =
            $self->parse_parlike($input, $RE{p}{filter}, $RE{p}{close});
    }

    $input->flush_empty;

    return $atom;
}

sub parse_block_list {
    my ($self, $input, $filter, $break) = @_;

    my  @list = ();
    my $last;

    $input->push_filter($filter || qr//);

    while (defined ($_ = $input->peek)) {
        last if /^$RE_ALL_ENV/;
        $last = defined $break && s/$break\n?$//;

        push @list, $self->parse_block($input);

        last if $last;
    }

    $input->pop_filter;

    return \@list;
}

sub parse_block {
    my ($self, $input) = @_;

    my $block = { line => $input->line };

    # > quotation
    if ($input->match($RE{quote}{open})) {
        $block->{type} = QUOTE;
        $block->{content} =
            $self->parse_block_list($input, $RE{quote}{filter}, $RE{quote}{close});

    # */-/o listing
    } elsif ($input->match($RE{ul}{open})) {
        my $open = $input->last_match;

        $block->{type} = UL;
        $block->{items} = [];

        do {
            push
                @{$block->{items}},
                $self->parse_block_list($input, $RE{ul}{filter}, $RE{ul}{close});
        } while ($input->match(qr/\Q$open\E/));

    # # enumeration
    } elsif ($input->match($RE{ul}{open})) {
        my $open = $input->last_match;

        $block->{type} = OL;
        $block->{items} = [];

        do {
            push
                @{$block->{items}},
                $self->parse_block_list($input, $RE{ol}{filter}, $RE{ol}{close});
        } while ($input->match(qr/\Q$open\E/));

    # :term: definition list
    } elsif ($input->match($RE{dl}{open})) {
        $block->{type} = DL;
        $block->{items} = [];

        do {
            my $term = $input->last_match;
            $term =~ s/^:|:\s$//g;

            push
                @{$block->{items}},
                [ $term, $self->parse_block_list($input, $RE{dl}{filter}, $RE{dl}{close}) ];
        } while ($input->match($RE{dl}{open}));

    } else {
        $block = $self->parse_atom($input);
    }

    return $block;
}

sub parse_struct_list {
    my ($self, $input, $filter, $break, $level) = @_;

    my  @list = ();
    my $last;

    $input->push_filter($filter || qr//);

    while (defined ($_ = $input->peek)) {
        last if /^$RE{h}{open}/ && ($& =~ tr/=//) < $level;
        $last = defined $break && s/$break\n?$//;

        push @list, $self->parse_structure($input);

        last if $last;
    }

    $input->pop_filter;

    return \@list;
}

sub parse_structure {
    my ($self, $input) = @_;

    my $struct = { line => $input->line };

    # = heading
    if ($input->match($RE{h}{open})) {
        my $match = $input->last_match;
        $struct->{type} = H;
        $struct->{level} = $match =~ tr/=//;
        $struct->{hidden} = $match =~ /\[/;
        $struct->{text} =
            $self->parse_parlike($input, $RE{h}{filter}, $RE{h}{close});

        $struct->{text} =~ s/[\r\n]//g;

        $input->flush_empty;

        $struct->{content} =
            $self->parse_struct_list($input, undef, undef, $struct->{level});

    } else {
        $struct = $self->parse_block($input);
    }

    return $struct;
}

sub parse {
    my ($self, $stream) = @_;

    my $input = Parse::WikiText::InputFilter->new($stream);

    my @list;
    while (defined $input->peek) {
        push @list, $self->parse_structure($input);
    }

    return \@list;
}

1;

__END__
