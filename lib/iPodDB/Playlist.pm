package iPodDB::Playlist;

=head1 NAME

iPodDB::Playlist - listing of songs in your database

=head1 SYNOPSIS

	my $playlist = iPodDB::Playlist->new( $frame );
	$playlist->load_songs( $database );

=head1 DESCRIPTION

This module provides a listing of the songs in the iPod database. It has a
few events attached to it such as: sorting the column on click, and poping up
the File menu when you right-click a row.

=cut

use base qw( Wx::ListCtrl Exporter );
use Wx qw( wxLC_REPORT wxLC_VRULES wxLC_HRULES wxLIST_STATE_SELECTED wxLIST_NEXT_ALL );
use Wx::Event qw( EVT_LIST_COL_CLICK EVT_LIST_ITEM_RIGHT_CLICK EVT_LIST_ITEM_SELECTED EVT_LIST_ITEM_DESELECTED EVT_LIST_BEGIN_DRAG );
use Wx::DND;

use strict;
use warnings;

use Path::Class;

use constant ARTIST     => 0;
use constant ALBUM      => 1;
use constant TITLE      => 2;

use constant ASCENDING  => 0;
use constant DESCENDING => 1;

our $VERSION    = '0.02';

our @EXPORT_OK  = qw( song_to_path );

my @columns     = qw( artist album title );
my @column_sort = ( ASCENDING ) x 3;

=head1 METHODS

=head2 new( $frame )

This creates the list widget and tries to automatically load the database
attached to the parent frame.

=cut

sub new {
	my $class  = shift;
	my $parent = shift;

	my $self = $class->SUPER::new( $parent, -1, [ -1, -1 ], [ -1, -1 ], wxLC_REPORT | wxLC_VRULES | wxLC_HRULES );

	bless $self, $class;

	$self->InsertColumn( $_, ucfirst( $columns[ $_ ] ) ) for 0..$#columns;

	EVT_LIST_COL_CLICK( $self, $self, \&on_column_click );
	EVT_LIST_ITEM_RIGHT_CLICK( $self, $self, \&on_row_right_click );
	EVT_LIST_ITEM_SELECTED( $self, $self, \&on_select );
	EVT_LIST_ITEM_DESELECTED( $self, $self, \&on_select );
	EVT_LIST_BEGIN_DRAG( $parent, $self, \&on_drag );

	$self->load_songs( $parent->database );

	return $self;
}

=head2 load_songs( $database )

This will add the songs found in the database to the listing as well as
update the status bar.

=cut

sub load_songs {
	my $self     = shift;
	my $database = shift;
	my $status   = $self->GetParent->status;

	return unless $database;

	$self->DeleteAllItems;

	my $time;
	my $filesize;
	for my $song ( $database->songs ) {
		my $id = $self->InsertItem( Wx::ListItem->new );

		for( 0..$#columns ) {
			my $column = $columns[ $_ ];
			$self->SetItem( $id, $_, $song->$column );
		}
		$self->SetItemData( $id, $song->id );

		$time     += $song->time;
		$filesize += $song->filesize;
	}

	$status->songs( scalar $database->songs );
	$status->time( $time );
	$status->size( $filesize );
	$self->SetColumnWidth( $_, -1 ) for 0..$#columns;
	$self->SortItems( sub { return $self->cmp_songs( ARTIST, @_ ); } );
}

=head2 as_songobject( [ @items ] )

This function returns an array of Mac::iPod::DB::Song objects based on a list of items.
If no list is provided the currently selected items are used.

=cut

sub as_songobject {
	my $self     = shift;
	my @items    = @_;
	my $database = $self->GetParent->database;
	my $item     = -1;
	my @songs;

	unless( @items ) {
		while( ( $item = $self->GetNextItem( $item, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED ) ) != -1 ) {
			push @items, $self->GetItemData( $item );
		}
	}

	push @songs, $database->song( $_ ) for @items;

	return @songs;
}

=head2 as_filedataobject( [ @items ] )

Return a Wx::FileDataObject from a list of items suitable for sending to the clipboard
or for processing in a drag and drop event. If no list is provided, the currently
selected items are used.

=cut

sub as_filedataobject {
	my $self  = shift;
	my @items = @_;
	my $path  = dir( $self->GetParent->preferences->mountpoint );
	my $files = Wx::FileDataObject->new;
	
	for my $song ( $self->as_songobject( @items ) ) {
		my $file = song_to_path( $path, $song );
		$files->AddFile( $file->stringify );
	}

	return $files;
}

=head2 cmp_songs( $column, $a, $b )

This is the sorting function.

=cut

sub cmp_songs {
	my $self     = shift;
	my $column   = shift;
	my $a        = shift;
	my $b        = shift;
	my $field    = $columns[ $column ];
	my $database = $self->GetParent->database;

	return 0 unless $database;

	if( $column_sort[ $column ] == DESCENDING ) {
		my $temp = $a;
		$a       = $b;
		$b       = $temp;
	}

	return $database->song( $a )->$field cmp $database->song( $b )->$field;
}

=head2 song_to_path( $directory, $song )

This utility function takes a directory (Path::Class object) and then the a song object. It then translates
the stored path to a path relative to the $directory. This method is available for export.

=cut

sub song_to_path {
	my $dir  = shift;
	my @path = split( ':', shift->path );

	for( 1..$#path ) {
		$dir = $_ == $#path ? $dir->file( $path[ $_ ] ) : $dir->subdir( $path[ $_ ] );
	}

	return $dir;
}

=head1 EVENTS

=head2 on_column_click( )

This event will sort the listing based on which column was clicked. It will
flip between ascending order and descending order on every click.

=cut

sub on_column_click {
	my $self   = shift;
	my $event  = shift;
	my $column = $event->GetColumn;

	$column_sort[ $column ] ^= 1;

	$self->SortItems( sub { return $self->cmp_songs( $column, @_ ); } );
}

=head2 on_row_right_click( )

This event will pop up the File menu as long as at least one song is selected.

=cut

sub on_row_right_click {
	my $self   = shift;
	my $event  = shift;
	my $parent = $self->GetParent;

	if( $self->GetSelectedItemCount ) {
		$parent->PopupMenu( iPodDB::Menu::File->new( $parent ), $event->GetPoint );
	}
}

=head2 on_select( )

This event enables or disables options on the File menu when items are selected
or deselected.

=cut

sub on_select {
	my $self   = shift;
	my $menu   = $self->GetParent->menu;
	my $enable = $self->GetSelectedItemCount ? 1 : 0;

	my @menus  = ( 'File', 'Copy To...', 'File', 'Copy' );

	while( @menus ) {
		my $item   = $menu->FindMenuItem( shift( @menus ), shift( @menus ) );
		$menu->Enable( $item, $enable );
	}
}

=head2 on_drag()

This event allows a user to drag files to a destination.

=cut

sub on_drag {
	my $self       = shift;
	my $playlist   = $self->playlist;

	return unless $playlist->GetSelectedItemCount;

	Wx::DropSource->new( $playlist->as_filedataobject, $self )->DoDragDrop;
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