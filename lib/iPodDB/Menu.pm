package iPodDB::Menu;

=head1 NAME

iPodDB::Menu - iPodDB Menu bar

=head1 SYNOPSIS

	my $menu = iPodDB::Menu->new( $frame );

=head1 DESCRIPTION

This adds a menu bar to the main iPodDB window. It has two menus:
File and Edit.

=cut

use base qw( Wx::MenuBar );

use strict;
use warnings;

use iPodDB::Playlist;
use iPodDB::Menu::File;
use iPodDB::Menu::Edit;

our $VERSION = '0.01';

=head1 METHODS

=head2 new( $frame )

Creates the menu bar and adds the File and Edit menus to it.

=cut

sub new {
	my $class  = shift;
	my $parent = shift;
	my $self   = $class->SUPER::new;

	bless $self, $class;

	$self->Append( iPodDB::Menu::File->new( $parent ), '&File' );
	$self->Append( iPodDB::Menu::Edit->new( $parent ), '&Edit' );

	$parent->SetMenuBar( $self );

	return $self;
}

=head1 AUTHOR

=over 4 

=item * Brian Cassidy E<lt>bricas@cpan.orgE<gt>

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by Brian Cassidy

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

1;