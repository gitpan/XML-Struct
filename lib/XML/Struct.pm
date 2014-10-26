package XML::Struct;
# ABSTRACT: Represent XML as data structure preserving element order
our $VERSION = '0.15'; # VERSION

use strict;
use XML::LibXML::Reader;
use List::Util qw(first);

use XML::Struct::Reader;
use XML::Struct::Writer;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(readXML writeXML simpleXML removeXMLAttr textValues);

sub readXML { # ( [$from], %options )
    my (%options) = @_ % 2 ? (from => @_) : @_;

    my %reader_options = (
        map { $_ => delete $options{$_} }
        grep { exists $options{$_} }
        qw(attributes whitespace path stream simple micro root ns depth)
    );
    if (%options) {
        if (exists $options{from} and keys %options == 1) {
            $reader_options{from} = $options{from};
        } else {
            $reader_options{from} = \%options;
        }
    }

    XML::Struct::Reader->new( %reader_options )->readDocument;
}

sub writeXML {
    my ($xml, %options) = @_;
    XML::Struct::Writer->new(%options)->write($xml); 
}

sub simpleXML {
    my ($element, %options) = @_;

    my $attributes = (!defined $options{attributes} or $options{attributes});

    if ($attributes eq 'remove') {
        $element = removeXMLAttr($element);
        $attributes = 0;
    }

    if (defined $options{depth} and $options{depth} !~ /^\+?\d+/) {
        $options{depth} = undef;
    }

    if ($options{root}) {
        my $root = $options{root};
        $root = $element->[0] if $root =~ /^[+-]?[0-9]+$/;

        $options{depth}-- if defined $options{depth};

        my $hash = $attributes
                ? _simple(1, [ dummy => {}, [$element] ], $options{depth})
                : _simple(0, [ dummy => [$element] ], $options{depth});

        return { $root => values %$hash };
    }

    my $hash = _simple($attributes, $element, $options{depth});
    $hash = { } unless ref $hash;

    return $hash;
}

sub _push_hash {
    my ($hash, $key, $value, $force) = @_;

    if ( exists $hash->{$key} ) {
        $hash->{$key} = [ $hash->{$key} ] if !ref $hash->{$key};
        push @{$hash->{$key}}, $value;
    } elsif ( $force ) {
        $hash->{$key} = [ $value ];
    } else {
        $hash->{$key} = $value;
    }
}

# hashifies attributes and child elements
sub _simple {
    my $with_attributes = shift;
    my ($children, $attributes) = $with_attributes ? ($_[0]->[2], $_[0]->[1]) : ($_[0]->[1]);
    my $depth = defined $_[1] ? $_[1] - 1 : undef;

    # empty element or characters only 
    if (!($attributes and %$attributes) and !first { ref $_ } @$children) {
        my $text = join "", @$children;
        return $text ne "" ? $text : { };
    }

    my $hash = { $attributes ? %$attributes : () };

    foreach my $child ( @$children ) {
        next unless ref $child; # skip mixed content text
        if (defined $depth and $depth < 0) {
            _push_hash( $hash, $child->[0], $child, 1 );
        } else {
            _push_hash( $hash, $child->[0] => _simple($with_attributes, $child, $depth) );
        }
    }

    return $hash; 
}

sub removeXMLAttr {
    my $node = shift;
    ref $node
        ? ( $node->[2]
            ? [ $node->[0], [ map { removeXMLAttr($_) } @{$node->[2]} ] ]
            : [ $node->[0] ] ) # empty element
        : $node;               # text node
}

# TODO: document (better name?)
sub textValues {
    my ($element, $options) = @_;
    # TODO: %options (e.g. join => " ")

    my $children = $element->[2];
    return "" if !$children;

    return join "", grep { $_ ne "" } map {
        ref $_ ?  textValues($_, $options) : $_
    } @$children;
}


1;

__END__
=pod

=head1 NAME

XML::Struct - Represent XML as data structure preserving element order

=head1 VERSION

version 0.15

=head1 SYNOPSIS

    use XML::Struct qw(readXML writeXML simpleXML removeXMLAttr);

    my $xml = readXML( "input.xml" );
    # [ root => { xmlns => 'http://example.org/' }, [ '!', [ x => {}, [42] ] ] ]

    my $doc = writeXML( $xml );
    # <?xml version="1.0" encoding="UTF-8"?>
    # <root xmlns="http://example.org/">!<x>42</x></root>

    my $simple = simpleXML( $xml, root => 'record' );
    # { record => { xmlns => 'http://example.org/', x => 42 } }

    my $xml2 = removeXMLAttr($xml);
    # [ root => [ '!', [ x => [42] ] ] ]

=head1 DESCRIPTION

L<XML::Struct> implements a mapping between XML and Perl data structures. By
default, the mapping preserves element order, so it also suits for
"document-oriented" XML.  In short, an XML element is represented as array
reference with three parts:

   [ $name => \%attributes, \@children ]

This data structure corresponds to the abstract data model of
L<MicroXML|http://www.w3.org/community/microxml/>, a simplified subset of XML.

If your XML documents don't contain relevant attributes, you can also choose
to map to this format:

   [ $name => \@children ]

Both parsing (with L<XML::Struct::Reader> or function C<readXML>) and
serializing (with L<XML::Struct::Writer> or function C<writeXML>) are fully
based on L<XML::LibXML>, so performance is better than L<XML::Simple> and
similar to L<XML::LibXML::Simple>.

=head1 MODULES

=over

=item L<XML::Struct::Reader>

Parse XML as stream into XML data structures.

=item L<XML::Struct::Writer>

Write XML data structures to XML streams for serializing, SAX processing, or
creating a DOM object.

=back

=head1 FUNCTIONS

The following functions are exported on request:

=head2 readXML( $source [, %options ] )

Read an XML document with L<XML::Struct::Reader>. The type of source (string,
filename, URL, IO Handle...) is detected automatically. Options not known to
XML::Struct::Reader are passed to L<XML::LibXML::Reader>.

=head2 writeXML( $xml [, %options ] )

Write an XML document/element with L<XML::Struct::Writer>.

=head2 simpleXML( $element [, %options ] )

Transform an XML document/element into simple key-value format as known from
L<XML::Simple>: Attributes and child elements are treated as hash keys with
their content as value. Text elements without attributes are converted to text
and empty elements without attributes are converted to empty hashes. The
following options are supported:

=over 4

=item root

Keep the root element (just as option C<KeepRoot> in L<XML::Simple>). In
addition one can set the name of the root element if a non-numeric value is
passed.

=item depth

Only transform to a given depth. See L<XML::Struct::Reader> for documentation.

All elements below the given depth are returned unmodified (not cloned) as
array elements:

    $data = simpleXML($xml, depth => 2)
    $content = $data->{x}->{y}; # array or scalar (if existing)

=item attributes

Assume input without attributes if set to a true value. The special value
C<remove> will first remove attributes, so the following three are equivalent:

    my @children = (['a'],['b']);

    simpleXML( [ $name => \@children ], attributes => 0 );
    simpleXML( removeXMLAttr( [ $name => \%attributes, \@children ] ), attributes => 0 );
    simpleXML( [ $name => \%attributes, \@children ], attributes => 'remove' );

=back

Key attributes (C<KeyAttr> in L<XML::Simple>) and the option C<ForceArray> are
not supported yet.

=head2 removeXMLAttr( $element )

Transform XML structure with attributes to XML structure without attributes.
The function does not modify the passed element but creates a modified copy.

=head1 EXAMPLE

To give an example, with L<XML::Struct::Reader>, this XML document:

    <root>
      <foo>text</foo>
      <bar key="value">
        text
        <doz/>
      </bar>
    </root>

is transformed to this structure:

    [
      "root", { }, [
        [ "foo", { }, "text" ],
        [ "bar", { key => "value" }, [
          "text", 
          [ "doz", { }, [ ] ]
        ] 
      ]
    ]

This module also supports a simple key-value (aka "data-oriented") format, as
used by L<XML::Simple>. With option C<simple> (or function C<simpleXML>) the
document given above woule be transformed to this structure:

    {
        foo => "text",
        bar => {
            key => "value",
            doz => {}
        }
    }

=head1 SEE ALSO

This module was first created to be used in L<Catmandu::XML> and turned out to
also become a replacement for L<XML::Simple>.

See L<XML::Twig> for another popular and powerfull module for stream-based
processing of XML documents.

See L<XML::Smart>, L<XML::Hash::LX>, L<XML::Parser::Style::ETree>,
L<XML::Fast>, and L<XML::Structured> for different representations of XML data
as data structures (feel free to implement converters from/to XML::Struct). See 

See L<XML::GenericJSON> for an (outdated and incomplete) attempt to capture more
parts of XML Infoset in another data structure.

See JSONx for a kind of reverse direction (JSON in XML).

=encoding utf8

=head1 AUTHOR

Jakob Voß

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Jakob Voß.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

