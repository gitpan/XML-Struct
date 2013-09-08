package XML::Struct::Reader;
# ABSTRACT: Read ordered XML from a stream
our $VERSION = '0.02'; # VERSION

use strict;
use Moo;

has whitespace => (is => 'rw', default => sub { 0 });
has attributes => (is => 'rw', default => sub { 1 });

use XML::LibXML::Reader qw(
    XML_READER_TYPE_ELEMENT
    XML_READER_TYPE_TEXT
    XML_READER_TYPE_CDATA
    XML_READER_TYPE_SIGNIFICANT_WHITESPACE
    XML_READER_TYPE_END_ELEMENT
); 


sub read {
    my ($self, $stream) = @_;
    $self->readNext( $stream, '' );
}


sub readElement {
    my ($self, $stream) = @_;

    my @element = ($stream->name);

    if ($self->attributes) {
        my $attr = $self->readAttributes($stream);
        my $children = $self->readContent($stream) if !$stream->isEmptyElement;
        if ($children) {
            push @element, $attr ||  { }, $children;
        } elsif( $attr ) {
            push @element, $attr;
        }
    } elsif( !$stream->isEmptyElement ) {
        push @element, $self->readContent($stream);
    }

    return \@element;
}


sub readNext {
    my ($self, $stream, $path) = @_;

    # TODO: normalize Path
    $path = "./$path" if $path !~ qr{^[./]}; # TODO: support ../
    $path .= '*' if $path =~ qr{/$};

    # print "path='$path'";

    my @parts = split '/', $path;
    my $depth = scalar @parts - 2;
    $depth += $stream->depth if $parts[0] eq '.'; # relative path

    my $name = $parts[-1];

    do { 
        return if !$stream->read; # error
        # printf "%d %s\n", ($stream->depth, $stream->nodePath) if $stream->nodeType == 1;
    } while( 
        $stream->nodeType != XML_READER_TYPE_ELEMENT || $stream->depth != $depth || 
        ($name ne '*' and $stream->name ne $name)
        # TODO: check full $stream->nodePath and possibly skip subtrees
        );


    $self->readElement($stream);
}


sub readAttributes {
    my ($self, $stream) = @_;
    return unless $stream->moveToFirstAttribute == 1;

    my $attr = { };
    do {
        $attr->{$stream->name} = $stream->value;
    } while ($stream->moveToNextAttribute);
    $stream->moveToElement;

    return $attr;
}


sub readContent {
    my ($self, $stream) = @_;

    my @children;
    while(1) {
        $stream->read;
        my $type = $stream->nodeType;

        if (!$type or $type == XML_READER_TYPE_END_ELEMENT) {
            return @children ? \@children : (); 
        }

        if ($type == XML_READER_TYPE_ELEMENT) {
            push @children, $self->readElement($stream);
        } elsif ($type == XML_READER_TYPE_TEXT || $type == XML_READER_TYPE_CDATA ) {
            push @children, $stream->value;
        } elsif ($type == XML_READER_TYPE_SIGNIFICANT_WHITESPACE && $self->whitespace) {
            push @children, $stream->value;
        }
    }
}

1;

__END__

=pod

=head1 NAME

XML::Struct::Reader - Read ordered XML from a stream

=head1 VERSION

version 0.02

=head1 SYNOPSIS

    my $stream = XML::LibXML::Reader->new( location => "file.xml" );
    my $stream = XML::Struct::Reader->new;
    my $data = $stream->read( $stream );

    # while 
    # depth < 
#    $transform = XML::Struct::Reader->new;

=head1 DESCRIPTION

This module reads from an XML stream via L<XML::LibXML::Reader> and return a
Perl data structure with ordered XML (see L<XML::Struct>).

=head1 METHODS

=head2 new( %options )

Create a new reader. By default whitespace is ignored, unless enabled with
option C<whitespace>. The option C<attributes> can be set to false to omit
all attributes from the result.

=head2 read( $stream )

Read the root element or the next element element. This method is a shortcut
for C<< readNext( $stream, '*' ) >>.

=head2 readElement( $stream )

Read an XML element from a stream and return it as array reference with element name,
attributes, and child elements. In contrast to method C<read>, this method expects
the stream to be at an element node (C<< $stream->nodeType == 1 >>) or bad things
might happed.

=head2 readNext( $stream, $path )

=head2 readContent( $stream )

Read all child elements of an XML element and return the result as array
reference or as empty list if no children were found.  Significant whitespace
is only included if option C<whitespace> is enabled.

=head readAttributes( $stream )

Read all XML attributes from a stream and return a hash reference or an empty
list if no attributes were found.

=head1 AUTHOR

Jakob Voß

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Jakob Voß.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
