package XML::Struct;
# ABSTRACT: Represent XML as data structure preserving element order
our $VERSION = '0.04'; # VERSION

use strict;
use XML::LibXML::Reader;
use List::Util qw(first);

use XML::Struct::Reader;
use XML::Struct::Writer;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(readXML writeXML hashifyXML textValues);

sub readXML { # ( [$from], %options )
    my (%options) = @_ % 2 ? (from => @_) : @_;

    my %reader = (
        map { $_ => delete $options{$_} }
        grep { exists $options{$_} } qw(attributes whitespace path stream hashify root)
    );
    if (%options) {
        if (exists $options{from} and keys %options == 1) {
            $reader{from} = $options{from};
        } else {
            $reader{from} = \%options;
        }
    }

    XML::Struct::Reader->new( %reader )->read;
}

sub writeXML {
    my ($xml, %options) = @_;
    XML::Struct::Writer->new(%options)->write($xml); 
}

sub hashifyXML {
    my ($element, %options) = @_;

    my $hash = _hashify(@_);
    $hash =  { } unless ref $hash;

    if ($options{root}) {
        my $root = $options{root};
        if ($root =~ /^[+-]?[0-9]+$/) {
            $root = $element->[0];
        }
        $hash = { $root => $hash };
    }

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

sub _hashify {
    my ($children, $attributes) = ($_[0]->[2], $_[0]->[1]);

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
        _push_hash( $hash, $child->[0] => _hashify($child) );
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

version 0.04

=head1 SYNOPSIS

    use XML::Struct qw(readXML writeXML hashifyXML);

    my $struct = readXML( "input.xml" );

    my $dom = writeXML( $struct );

    ...

=head1 DESCRIPTION

L<XML::Struct> implements a mapping of "document-oriented" XML to Perl data
structures.  The mapping preserves element order but only XML elements,
attributes, and text nodes (including CDATA-sections) are included. In short,
an XML element is represented as array reference:

   [ $name => \%attributes, \@children ]

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

The reverse transformation can be applied with L<XML::Struct::Writer>.

Key-value (aka "data-oriented") XML, as known from L<XML::Simple> can be
created with C<hashifyXML>:

    {
        foo => "text",
        bar => {
            key => "value",
            doz => {}
        }
    }

Both parsing and serializing are fully based on L<XML::LibXML>, so performance
is better than L<XML::Simple> and similar to L<XML::LibXML::Simple>.

=head1 EXPORTED FUNCTIONS

The following functions can be exported on request:

=head2 readXML( [ $source ] , [ %options ] )

Read an XML document with L<XML::Struct::Reader>. The type of source (string,
filename, URL, IO Handle...) is detected automatically.

=head2 writeXML( $xml, %options )

Write an XML document with L<XML::Struct::Writer>.

=head2 hashify( $element [, %options ] )

Transforms an XML element into a flattened hash, similar to what L<XML::Simple>
returns. Attributes and child elements are treated as hash keys with their
content as value. Text elements without attributes are converted to text and
empty elements without attributes are converted to empty hashes.

The option C<root> works similar to C<KeepRoot> in L<XML::Simple>.

Key attributes (C<KeyAttr> in L<XML::Simple>) and the options 
C<ForceArray> are not supported (yet?).

=head1 SEE ALSO

L<XML::Simple>, L<XML::Fast>, L<XML::GenericJSON>, L<XML::Structured>,
L<XML::Smart>

=encoding utf8

=head1 AUTHOR

Jakob Voß

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Jakob Voß.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
