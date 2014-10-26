package XML::Struct;
# ABSTRACT: Represent XML as data structure preserving element order
our $VERSION = '0.10'; # VERSION

use strict;
use XML::LibXML::Reader;
use List::Util qw(first);

use XML::Struct::Reader;
use XML::Struct::Writer;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(readXML writeXML simpleXML textValues);

sub readXML { # ( [$from], %options )
    my (%options) = @_ % 2 ? (from => @_) : @_;

    my %reader_options = (
        map { $_ => delete $options{$_} }
        grep { exists $options{$_} } qw(attributes whitespace path stream simple root)
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

    if ($options{root}) {
        my $root = $options{root};
        $root = $element->[0] if $root =~ /^[+-]?[0-9]+$/;

        my $hash = $attributes
                ? _simple(1, [ dummy => {}, [$element] ])
                : _simple(0, [ dummy => [$element] ]);

        return { $root => values %$hash };
    }

    my $hash = _simple($attributes, $element);
    $hash = { } unless ref $hash;

    return $hash;
}

sub _push_hash {
    my ($hash, $key, $value) = @_;

    if ( exists $hash->{$key} ) {
        $hash->{$key} = [ $hash->{$key} ] if !ref $hash->{$key};
        push @{$hash->{$key}}, $value;
    } else {
        $hash->{$key} = $value;
    }
}

# hashifies attributes and child elements
sub _simple {
    my $with_attributes = shift;
    my ($children, $attributes) = $with_attributes ? ($_[0]->[2], $_[0]->[1]) : ($_[0]->[1]);

    # empty element or characters only 
    if (!($attributes and %$attributes) and !first { ref $_ } @$children) {
        my $text = join "", @$children;
        return $text ne "" ? $text : { };
    }

    my $hash = { };

    foreach my $key ( keys  %$attributes ) {
        _push_hash( $hash, $key => $attributes->{$key} );
    }            

    foreach my $child ( @$children ) {
        next unless ref $child; # skip mixed content text
        _push_hash( $hash, $child->[0] => _simple($with_attributes, $child) );
    }

    return $hash; 
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

version 0.10

=head1 SYNOPSIS

    use XML::Struct qw(readXML writeXML simpleXML);

    my $xml = readXML( "input.xml" );
    # [ root => { xmlns => 'http://example.org/' }, [ '!', [x => {}, [42]] ] ]

    my $doc = writeXML( $xml );
    # <?xml version="1.0" encoding="UTF-8"?>
    # <root xmlns="http://example.org/">!<x>42</x></root>

    my $simple = simpleXML( $xml, root => 'record' );
    # { record => { xmlns => 'http://example.org/', x => 42 } }

=head1 DESCRIPTION

L<XML::Struct> implements a mapping between XML and Perl data structures. By default,
the mapping preserves element order, so it also suits for "document-oriented" XML.

In short, an XML element is represented as array reference:

   [ $name => \%attributes, \@children ]

If your XML documents don't contain relevant attributes, you can also choose this format:

   [ $name => \@children ]

The module L<XML::Struct::Reader> (or function C<readXML>) can be used to parse
XML into this structure and the module L<XML::Struct::Writer> (or function
C<writeXML) does the reverse.

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
          [ "doz", { } ]
        ] 
      ]
    ]

L<XML::Struct> also supports a simple key-value (aka "data-oriented") format,
as used by L<XML::Simple>. With option C<simple> (or function C<simpleXML>) the
document given above woule be transformed to this structure:

    {
        foo => "text",
        bar => {
            key => "value",
            doz => {}
        }
    }

Both parsing and serializing are fully based on L<XML::LibXML>, so performance
is better than L<XML::Simple> and similar to L<XML::LibXML::Simple>.

=head1 FUNCTIONS

The following functions can be exported on request:

=head2 readXML( $source [, %options ] )

Read an XML document with L<XML::Struct::Reader>. The type of source (string,
filename, URL, IO Handle...) is detected automatically.

=head2 writeXML( $xml [, %options ] )

Write an XML document with L<XML::Struct::Writer>.

=head2 simpleXML( $element [, %options ] )

Transforms an XML element into a flattened hash, similar to what L<XML::Simple>
returns. Attributes and child elements are treated as hash keys with their
content as value. Text elements without attributes are converted to text and
empty elements without attributes are converted to empty hashes.

The option C<root> works similar to C<KeepRoot> in L<XML::Simple>.

Key attributes (C<KeyAttr> in L<XML::Simple>) and the option C<ForceArray> are
not supported yet.

=head1 SEE ALSO

L<XML::Simple>, L<XML::Twig>, L<XML::Fast>, L<XML::GenericJSON>,
L<XML::Structured>, L<XML::Smart>...

=encoding utf8

=head1 AUTHOR

Jakob Voß

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Jakob Voß.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

