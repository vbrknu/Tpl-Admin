#!/usr/bin/perl -w -- 
#
# 
# To get wxPerl visit http://wxPerl.sourceforge.net/
#

use Wx 0.15 qw[:allclasses];
use strict;
use Core;
use feature 'say';
# begin wxGlade: dependencies
# end wxGlade

# begin wxGlade: extracode
# end wxGlade


package MyFrame;

use Wx;
use Wx qw[:everything];
use Wx::Event qw( EVT_BUTTON EVT_CLOSE EVT_RADIOBOX );
use Wx::Perl::TextValidator;
use base qw(Wx::Frame Class::Accessor::Fast);
use strict;
use Wx::Locale gettext => '_T';

__PACKAGE__->mk_ro_accessors( qw(numeric string) );

sub new {
    my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
    $parent = undef              unless defined $parent;
    $id     = -1                 unless defined $id;
    $title  = ""                 unless defined $title;
    $pos    = wxDefaultPosition  unless defined $pos;
    $size   = wxDefaultSize      unless defined $size;
    $name   = ""                 unless defined $name;

    # begin wxGlade: MyFrame::new
    $style = wxDEFAULT_FRAME_STYLE 
        unless defined $style;
    my $numval = Wx::Perl::TextValidator->new( '\d' );
    my $numvall = Wx::Perl::TextValidator->new( '\d' );
    
    $self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
    $self->{text_ctrl_1} = Wx::TextCtrl->new($self, wxID_ANY, "", wxDefaultPosition, wxDefaultSize, );
    $self->{button_1} = Wx::Button->new($self, wxID_ANY, _T("Get Picks"));
    $self->{label_1} = Wx::StaticText->new($self, wxID_ANY, _T("From:"), wxDefaultPosition, wxDefaultSize, );
    $self->{text_ctrl_2} = $self->{numeric} = Wx::TextCtrl->new($self, wxID_ANY, "", wxDefaultPosition, wxDefaultSize, );
    $self->{label_2} = Wx::StaticText->new($self, wxID_ANY, _T("To:    "), wxDefaultPosition, wxDefaultSize, );
    $self->{text_ctrl_3} = $self->{numeric} = Wx::TextCtrl->new($self, wxID_ANY, "", wxDefaultPosition, wxDefaultSize, );
    $self->{radio_box_1} = Wx::RadioBox->new($self, wxID_ANY, _T("Slam?"), wxDefaultPosition, wxDefaultSize, [_T("Yes"), _T("No")], 2, wxRA_SPECIFY_ROWS);
    $self->{text_ctrl_4} = Wx::TextCtrl->new($self, wxID_ANY, "", wxDefaultPosition, wxDefaultSize, wxTE_MULTILINE);

    $self->__set_properties();
    $self->__do_layout();
    # end wxGlade
    
    $self->SetIcon(Wx::GetWxPerlIcon);
    
    # setting up the default radio button option
    $TPL::Admin::Core::slam = 1;
    
    $self->{text_ctrl_2}->SetValidator ( $numval );
    $self->{text_ctrl_3}->SetValidator ( $numvall );
    
    EVT_RADIOBOX( $self, $self->{radio_box_1}, \&OnRadio );
    EVT_BUTTON( $self, $self->{button_1}, \&GetURL );    
    EVT_CLOSE( $self, \&OnClose );
    
    return $self;
}

 
sub GetURL {
        my ( $self, $event ) = @_;
        
        if ( ($TPL::Admin::Core::tourney_url = $self->{text_ctrl_1}->GetValue()) and
            ($TPL::Admin::Core::oop_post     = $self->{text_ctrl_2}->GetValue()) and
            ($TPL::Admin::Core::to_post      = $self->{text_ctrl_3}->GetValue())) {
                TPL::Admin::Core::check_if_poll();  
                TPL::Admin::Core::get_oop();
                TPL::Admin::Core::main();
                my $output = TPL::Admin::Core::slurp_file_to_scalar($TPL::Admin::Core::output_file); 
                PutText( $self->{text_ctrl_4}, $$output );
            } else { 
                Wx::MessageBox("There is nothing in the URL box", "Warning", wxOK, $self);
            }
}


sub OnRadio {
    my( $self, $event ) = @_;
    
    if ( $event->GetString() eq 'No' ) {
        $TPL::Admin::Core::slam = 0;
    } else {
        $TPL::Admin::Core::slam = 1;
    }
}


sub PutText {
    my ( $self, $text ) = @_;
    $self->AppendText($text);
}

sub OnClose {
    my ( $self, $event ) = @_;
    $self->Destroy();
}

sub __set_properties {
    my $self = shift;
    # begin wxGlade: MyFrame::__set_properties
    $self->SetTitle(_T("TplAdmin"));
    $self->SetSize(Wx::Size->new(800, 600));
    $self->SetBackgroundColour(Wx::Colour->new(95, 159, 159));
    $self->{text_ctrl_1}->SetMinSize(Wx::Size->new(780, 25));
    $self->{text_ctrl_1}->SetToolTipString(_T("Copy the URL of the specific thread you want to process. The URL should be of the first page of that thread."));
    $self->{button_1}->SetToolTipString(_T("If all is set in the other fields, click this to start the processing"));
    $self->{label_1}->SetToolTipString(_T("This is the post number in the thread where the Order of Play has been posted for the respective posts that will be checked."));
    $self->{text_ctrl_2}->SetToolTipString(_T("This is the post number in the thread where the Order of Play has been posted for the respective posts that will be checked."));
    $self->{label_2}->SetToolTipString(_T("Indicate a post number up until where we should look for posts for the selected order of play."));
    $self->{text_ctrl_3}->SetToolTipString(_T("Indicate a post number up until where we should look for posts for the selected order of play."));
    $self->{radio_box_1}->SetToolTipString(_T("Is the tournament a grand slam?"));
    $self->{radio_box_1}->SetSelection(0);
    $self->{text_ctrl_4}->SetMinSize(Wx::Size->new(780, 400));
    # end wxGlade
}

sub __do_layout {
    my $self = shift;
    # begin wxGlade: MyFrame::__do_layout
    $self->{sizer_1} = Wx::BoxSizer->new(wxVERTICAL);
    $self->{sizer_2} = Wx::BoxSizer->new(wxVERTICAL);
    $self->{sizer_3} = Wx::BoxSizer->new(wxHORIZONTAL);
    $self->{sizer_4} = Wx::BoxSizer->new(wxVERTICAL);
    $self->{sizer_6} = Wx::BoxSizer->new(wxHORIZONTAL);
    $self->{sizer_5} = Wx::BoxSizer->new(wxHORIZONTAL);
    $self->{sizer_2}->Add($self->{text_ctrl_1}, 0, wxALIGN_CENTER_HORIZONTAL, 0);
    $self->{sizer_2}->Add($self->{button_1}, 0, wxALL, 10);
    $self->{sizer_5}->Add($self->{label_1}, 0, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 25);
    $self->{sizer_5}->Add($self->{text_ctrl_2}, 0, wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 0);
    $self->{sizer_4}->Add($self->{sizer_5}, 1, wxEXPAND, 0);
    $self->{sizer_6}->Add($self->{label_2}, 0, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 25);
    $self->{sizer_6}->Add($self->{text_ctrl_3}, 0, wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 0);
    $self->{sizer_4}->Add($self->{sizer_6}, 1, wxEXPAND, 0);
    $self->{sizer_3}->Add($self->{sizer_4}, 1, wxEXPAND, 5);
    $self->{sizer_3}->Add($self->{radio_box_1}, 0, wxRIGHT|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 450);
    $self->{sizer_2}->Add($self->{sizer_3}, 1, wxALL|wxEXPAND, 0);
    $self->{sizer_1}->Add($self->{sizer_2}, 1, wxALL|wxEXPAND, 10);
    $self->{sizer_1}->Add($self->{text_ctrl_4}, 0, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 10);
    $self->SetSizer($self->{sizer_1});
    $self->Layout();
    # end wxGlade
}


# end of class MyFrame

1;

1;

package main;

unless(caller){
    my $local = Wx::Locale->new("??"); # replace with ??
    $local->AddCatalog("app"); # replace with the appropriate catalog name

    local *Wx::App::OnInit = sub{1};
    my $app = Wx::App->new();
    Wx::InitAllImageHandlers();

    my $frame_1 = MyFrame->new();
    
    $app->SetTopWindow($frame_1);
    $frame_1->Show(1);
    
    $app->MainLoop();
    
}

