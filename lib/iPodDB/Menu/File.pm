package iPodDB::Menu::File;

=head1 NAME

iPodDB::Menu::File - the file menu

=head1 SYNOPSIS

	my $file = iPodDB::Menu::File->new( $frame );

=head1 DESCRIPTION

This is the File menu portion of the menu bar. It is also a popup menu
when a user right-clicks a song.

=cut

use base qw( Wx::Menu );
use Wx qw( wxOK wxID_OK wxTheClipboard );
use Wx::Event qw( EVT_MENU );
use Wx::DND;

use strict;
use warnings;

use File::Copy;
use Path::Class;

our $VERSION = '0.01';

=head1 METHODS

=head2 new( $frame )

Creates the menu and sets up the callbacks when menu items are clicked.

=cut

sub new {
	my $class  = shift;
	my $parent = shift;
	my $self   = $class->SUPER::new;

	bless $self, $class;

	$self->Append( my $copyto_id = Wx::NewId, "&Copy To...\tCtrl-T" );
	$self->Append( my $copy_id   = Wx::NewId, "&Copy\tCtrl-C" );

	unless( $parent->playlist->GetSelectedItemCount ) {
		$self->Enable( $copyto_id, 0 );
		$self->Enable( $copy_id, 0 );
	}

	EVT_MENU( $parent, $copyto_id, \&on_copyto );
	EVT_MENU( $parent, $copy_id, \&on_copy );

	return $self;
}

=head2 on_copyto( )

When the "Copy To..." option is selected this callback is triggered. It will popup
a dialog asking the user to select a destination directory, then a progress dialog
to show them the progress of the copy operation.

=cut

sub on_copyto {
	my $self     = shift;
	my $playlist = $self->playlist;
	my $path     = dir( $self->preferences->mountpoint );

	return unless $playlist->GetSelectedItemCount;

	my $dialog = Wx::DirDialog->new( $self, 'Choose a destination directory' );

	return unless $dialog->ShowModal == wxID_OK;

	my $dpath    = dir( $dialog->GetPath );
	my $progress = Wx::ProgressDialog->new( 'Copying Files...', 'Copying files to ' . $dialog->GetPath, $playlist->GetSelectedItemCount );

	my $i = 0;
	for my $song ( $playlist->selected_songs ) {
		my $source      = songpath_to_dir( $path, $song->path );
		my $file        = $source->basename;
		my $destination = $dpath->file( $file );

		$progress->Update( $i++, 'Copying files to ' . $dpath . ":\n" . $file );

		eval{ copy( $source, $destination ); };

		if( $@ ) {
			Wx::MessageDialog->new( $self, "Cannot copy file: $@", 'Error',	wxOK )->ShowModal;
			last;
		}
	}
	$progress->Destroy;
}

=head2 on_copyto( )

When the "Copy" option is selected this callback is triggered. It simply copies the
list of selected files to the clipboard. Thus, a user can do a paste operation in to
any folder they desire.

=cut

sub on_copy {
	my $self       = shift;
	my $playlist   = $self->playlist;
	my $path       = dir( $self->preferences->mountpoint );

	return unless $playlist->GetSelectedItemCount;

	my $files      = Wx::FileDataObject->new;

	for my $song ( $playlist->selected_songs ) {
		my $file = songpath_to_dir( $path, $song->path );
		$files->AddFile( $file->stringify );
	}

	wxTheClipboard->Open;
	wxTheClipboard->SetData( $files );
	wxTheClipboard->Close;
}

=head2 songpath_to_dir( $dir, $songpath )

This utility function takes a directory (Path::Class object) and then the path of a song (as stored
in the iPod database) and puts the two together.

=cut

sub songpath_to_dir {
	my $dir  = shift;
	my @path = split( ':', shift );

	for( 1..$#path ) {
		$dir = $_ == $#path ? $dir->file( $path[ $_ ] ) : $dir->subdir( $path[ $_ ] );
	}

	return $dir;
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