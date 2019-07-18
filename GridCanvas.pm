package GridCanvas;

use warnings;
use strict;

use Glib qw/TRUE FALSE/;
use Gtk2;
use Cairo;

use Glib::Object::Subclass
	Gtk2::DrawingArea::,
	signals => {
		expose_event => \&expose,
	};

sub grid2px {

    my ($self,$x,$y) = @_;
    my @corners = @{ $self->{corners} };

    my $f1 = $x/($self->{rows}-1);
    my $f2 = $y/($self->{cols}-1);

    my $x1 = $corners[0]->[0];
    my $x2 = $corners[1]->[0];
    my $x3 = $corners[3]->[0];
    my $x4 = $corners[2]->[0];
    my $y1 = $corners[0]->[1];
    my $y2 = $corners[1]->[1];
    my $y3 = $corners[3]->[1];
    my $y4 = $corners[2]->[1];

    my $x5 = $x2*$f1 + $x1*(1-$f1);
    my $x6 = $x4*$f1 + $x3*(1-$f1);
    my $x7 = $x3*$f2 + $x1*(1-$f2);
    my $x8 = $x4*$f2 + $x2*(1-$f2);
    my $y5 = $y2*$f1 + $y1*(1-$f1);
    my $y6 = $y4*$f1 + $y3*(1-$f1);
    my $y7 = $y3*$f2 + $y1*(1-$f2);
    my $y8 = $y4*$f2 + $y2*(1-$f2);

    my $m1 = $x6 == $x5 ? undef : ($y6-$y5)/($x6-$x5);
    my $b1 = defined $m1 ? $y5 - $m1*$x5 : undef;
    my $m2 = ($y8-$y7)/($x8-$x7);
    my $b2 = $y7 - $m2*$x7;
    my $x9 = ! defined $m1 ? $x5 : ($b2-$b1)/($m1-$m2);
    my $y9 = $m2*$x9+$b2;

    return ($x9,$y9);

}

sub man_to_rect {

    my ($self, $ref) = @_;


    my ($x1,$y1) = $self->{cr}->device_to_user($ref->[0]->[0],$ref->[0]->[1]);
    my ($x2,$y2) = $self->{cr}->device_to_user($ref->[1]->[0],$ref->[1]->[1]);
    my @corners = ( [$x1,$y1], [$x2,$y2] );
    if (defined $ref->[2]) {
        my ($x3,$y3) = $self->{cr}->device_to_user($ref->[2]->[0],$ref->[2]->[1]);
        my $m = ($y2-$y1)/($x2-$x1);
        my $x4 = ($y1 - $y3 + $m*$x3 + $x1/$m) / ($m + 1/$m);
        my $y4 = $m*$x4 - $m*$x3 + $y3;
        my $x5 = ($y2 - $y3 + $m*$x3 + $x2/$m) / ($m + 1/$m);
        my $y5 = $m*$x5 - $m*$x3 + $y3;
        push @corners, [$x5,$y5];
        push @corners, [$x4,$y4];
    }
    return @corners;

}

sub set_pixbuf {

    my ($self, $pb) = @_;
    $self->{pixbuf} = $pb;
    $self->update();

}

sub get_pixbuf {

    my ($self) = @_;
    return $self->{pixbuf};

}

sub update {

    my ($self) = @_;
    my $alloc = $self->allocation;
    my $w = $alloc->width;
    my $h = $alloc->height;
    $self->queue_draw_area(0,0,$w,$h);
    #$self->queue_draw();
    Gtk2->main_iteration_do(FALSE);

}

sub set_selbox {

    my ($self, @coords) = @_;
    if (! defined $coords[0]) {
        $self->{selbox} = undef;
        return;
    }
    $self->{selbox} = [@coords] if (defined $coords[0]);;
    $self->update();

}

sub sel_spot {

    my ($self,$coords) = @_;
    if (! defined $coords) {
        $self->{selspot} = undef;
        $self->update();
        return 0;
    }
    else {
        if (defined $self->{selspot} && $self->{selspot}->[0] == $coords->[0]
          && $self->{selspot}->[1] == $coords->[1]) {
            $self->{selspot} = undef;
            $self->update();
            return 0;
        }
        else {
            $self->{selspot} = $coords;
            $self->update();
            return 1;
        }
    }

}
sub toggle_feature {

    my ($self,$coords) = @_;
    if (! defined $coords) {
        $self->{feature} = {};
        $self->update();
        return 0;
    }
    else {
        if ($self->{feature}->{$coords->[0]}->{$coords->[1]}) {
            delete $self->{feature}->{$coords->[0]}->{$coords->[1]};
            $self->update();
            return 0;
        }
        else {
            $self->{feature}->{$coords->[0]}->{$coords->[1]} = 1;
            $self->update();
            return 1;
        }
    }

}

sub toggle_mask {

    my ($self,$coords) = @_;
    if (! defined $coords) {
        $self->{masked} = {};
        $self->update();
        return 0;
    }
    else {
        if ($self->{masked}->{$coords->[0]}->{$coords->[1]}) {
            delete $self->{masked}->{$coords->[0]}->{$coords->[1]};
            $self->update();
            return 0;
        }
        else {
            $self->{masked}->{$coords->[0]}->{$coords->[1]} = 1;
            $self->update();
            return 1;
        }
    }

}

sub is_masked {

    my ($self,$coords) = @_;
    return $self->{masked}->{$coords->[0]}->{$coords->[1]} // 0;

}


sub scale {

    my ($self,$sf) = @_;
    my $cr = $self->{cr};

    $self->{zoom} *= $sf if ($sf);

    # zoom to 100% if passed -1
    $self->{zoom} = 1 if ($sf == -1);

    $self->update();

}

sub draw {

	my $self = shift;
	my $cr = $self->{cr};

	return FALSE unless $cr;
    return FALSE unless defined $self->{pixbuf};

    $cr->scale( $self->{zoom}, $self->{zoom} );
	
    $cr->save;
    my $pb = $self->{pixbuf};
    Gtk2::Gdk::Cairo::Context::set_source_pixbuf(
        $cr,
        $pb,
        0,0
    );
    $cr->get_source->set_filter('nearest');
    $cr->paint;
    $cr->restore;

    $self->set_size_request($pb->get_width * $self->{zoom}, $pb->get_height * $self->{zoom});

    # draw zoom box, if defined
    if (defined $self->{selbox}) {
        $cr->save;
        $cr->set_source_rgba(1.0, 0.0, 0.0, 0.5);
        my ($w,$h) = $cr->device_to_user_distance(1.0,0.0);
        $cr->set_line_width($w);
        my ($x1,$y1) = $cr->device_to_user($self->{selbox}->[0], $self->{selbox}->[1]);
        my ($x2,$y2) = $cr->device_to_user($self->{selbox}->[2], $self->{selbox}->[3]);
        $cr->rectangle($x1, $y1, $x2-$x1, $y2-$y1);
        $cr->stroke;
        $cr->restore;
    }

    # draw manual gridding box, if defined
    if (defined $self->{man_points}) {
        $cr->save;
        $cr->set_source_rgba(1.0, 0.0, 0.0, 0.5);
        my ($w,$h) = $cr->device_to_user_distance(1.0,0.0);
        $cr->set_line_width($w);
        my @corners = $self->man_to_rect( $self->{man_points} );
        my ($x1,$y1) = ($corners[0]->[0],$corners[0]->[1]);
        my ($x2,$y2) = ($corners[1]->[0],$corners[1]->[1]);
        $cr->move_to($x1,$y1);
        $cr->line_to($x2,$y2);
        if (defined $corners[2]) {
            my ($x3,$y3) = ($corners[2]->[0],$corners[2]->[1]);
            my ($x4,$y4) = ($corners[3]->[0],$corners[3]->[1]);
            $cr->line_to($x3,$y3);
            $cr->line_to($x4,$y4);
            $cr->close_path();
        }
        $cr->stroke;
        $cr->restore;
    }

    #highlight specified pixels

    if ($self->{show_hilite} && defined $self->{hilite}) {

        $cr->save;
        $cr->set_source_surface($self->{hilite},0,0);
        $cr->get_source->set_filter('nearest');
        $cr->paint;
        $cr->restore;
        
    }

    #highlight selected spot, if any
    if (defined $self->{selspot} && defined $self->{corners}) {
        $cr->save;
        $cr->set_source_rgba(1.0, 1.0, 0.0, 0.4);
        $cr->set_line_width(0);
        my ($x,$y) = @{ $self->{selspot} };
        my ($x1,$y1) = $self->grid2px($x-0.5,$y-0.5);
        my ($x2,$y2) = $self->grid2px($x+0.5,$y-0.5);
        my ($x3,$y3) = $self->grid2px($x+0.5,$y+0.5);
        my ($x4,$y4) = $self->grid2px($x-0.5,$y+0.5);
        $cr->move_to($x1,$y1);
        $cr->line_to($x2,$y2);
        $cr->line_to($x3,$y3);
        $cr->line_to($x4,$y4);
        $cr->close_path;
        $cr->fill;
        $cr->restore;
    }

    #hilight masked spots
    if (keys %{$self->{masked}} > 0) {
        $cr->save;
        $cr->set_source_rgba(1.0, 0.0, 0.0, 0.6);
        $cr->set_line_width(0);
        for my $x (keys %{$self->{masked}}) {
            for my $y (keys %{$self->{masked}->{$x}}) {
                my ($x1,$y1) = $self->grid2px($x-0.5,$y-0.5);
                my ($x2,$y2) = $self->grid2px($x+0.5,$y-0.5);
                my ($x3,$y3) = $self->grid2px($x+0.5,$y+0.5);
                my ($x4,$y4) = $self->grid2px($x-0.5,$y+0.5);
                $cr->move_to($x1,$y1);
                $cr->line_to($x2,$y2);
                $cr->line_to($x3,$y3);
                $cr->line_to($x4,$y4);
                $cr->close_path;
            }
        }
        $cr->fill;
        $cr->restore;
    }


    #draw grid on top of everything

    if ($self->{show_grid} && defined $self->{corners}) {
        $cr->save;
        $cr->set_source_rgba(1.0, 0.0, 0.0, 0.5);
        my ($w,$h) = $cr->device_to_user_distance(1.0,0.0);
        $cr->set_line_width($w);

        for my $x (0..$self->{cols}) {
            $x -= 0.5;
            my ($x1,$y1) = $self->grid2px($x,-.5);
            my ($x2,$y2) = $self->grid2px($x,$self->{rows}-.5);
            #($x1,$y1) = map {$_ * $self->{zoom}} ($x1,$y1);
            #($x2,$y2) = map {$_ * $self->{zoom}} ($x2,$y2);
            #($x1,$y1) = $cr->device_to_user($x1,$y1);
            #($x2,$y2) = $cr->device_to_user($x2,$y2);
            $cr->move_to($x1,$y1);
            $cr->line_to($x2,$y2);
        }
        for my $y (0..$self->{rows}) {
            $y -= 0.5;
            my ($x1,$y1) = $self->grid2px(-.5,$y);
            my ($x2,$y2) = $self->grid2px($self->{cols}-.5,$y);
            #($x1,$y1) = map {$_ * $self->{zoom}} ($x1,$y1);
            #($x2,$y2) = map {$_ * $self->{zoom}} ($x2,$y2);
            #($x1,$y1) = $self->{cr}->device_to_user($x1,$y1);
            #($x2,$y2) = $self->{cr}->device_to_user($x2,$y2);
            $cr->move_to($x1,$y1);
            $cr->line_to($x2,$y2);
        }
        $cr->stroke;
        $cr->restore;

    }

    #hilight featured spots
    if (keys %{$self->{feature}} > 0 && defined $self->{corners}) {
        $cr->save;
        $cr->set_source_rgba(0.0, 1.0, 0.0, 1.0);
        #$cr->set_line_width(0);
        my ($w,$h) = $cr->device_to_user_distance(1.0,0.0);
        $cr->set_line_width($w*2);
        for my $x (keys %{$self->{feature}}) {
            for my $y (keys %{$self->{feature}->{$x}}) {
                my ($x1,$y1) = $self->grid2px($x-0.5,$y-0.5);
                my ($x2,$y2) = $self->grid2px($x+0.5,$y-0.5);
                my ($x3,$y3) = $self->grid2px($x+0.5,$y+0.5);
                my ($x4,$y4) = $self->grid2px($x-0.5,$y+0.5);
                $cr->move_to($x1,$y1);
                $cr->line_to($x2,$y2);
                $cr->line_to($x3,$y3);
                $cr->line_to($x4,$y4);
                $cr->close_path;
            }
        }
        #$cr->fill;
        $cr->stroke;
        $cr->restore;
    }
	
	return TRUE;
}

sub expose {

	my ($self, $event) = @_;

	my $cr = Gtk2::Gdk::Cairo::Context->create($self->window);
	$cr->rectangle ($event->area->x,
			$event->area->y,
			$event->area->width,
			$event->area->height);
	$cr->clip;
	$self->{cr} = $cr;
	
	$self->draw;

	return FALSE;
}

sub INIT_INSTANCE {

	my $self = shift;

	$self->{line_width} = 0.05;
	$self->{radius}     = 0.42;
    $self->{zoom} = 1;
    $self->{show_grid} = 1;
    $self->{show_hilite} = 0;

    $self->add_events('GDK_BUTTON_PRESS_MASK');
    $self->add_events('GDK_BUTTON_RELEASE_MASK');
    $self->add_events('GDK_POINTER_MOTION_MASK');
    $self->add_events('GDK_ENTER_NOTIFY_MASK');
    $self->add_events('GDK_LEAVE_NOTIFY_MASK');

}

#sub set_grid {
#
    #my ($self, $ref, $w, $h) = @_;
    #if (! defined $ref) {
        #$self->{corners} = undef;
        #return;
    #}
    #$self->{corners} = $ref;
    #$self->{cols} = $w;
    #$self->{rows} = $h;
    #return;
#
#}

sub set_show_grid {
    
    my ($self, $bool) = @_;
    $self->{show_grid} = $bool;

}

sub set_show_highlight {
    
    my ($self, $bool) = @_;
    $self->{show_hilite} = $bool;

}


sub px2grid {

    my ($self,$x9,$y9) = @_;
    return if (! defined $self->{corners});
    my @corners = @{ $self->{corners} };
    ($x9,$y9) = $self->{cr}->device_to_user($x9,$y9);
    my $x1 = $corners[0]->[0];
    my $x2 = $corners[1]->[0];
    my $x3 = $corners[3]->[0];
    my $x4 = $corners[2]->[0];
    my $y1 = $corners[0]->[1];
    my $y2 = $corners[1]->[1];
    my $y3 = $corners[3]->[1];
    my $y4 = $corners[2]->[1];

    #locate x coord
    my $num   = ($y4 == $y3) ? $y9 - $y1
            : $y9 - ($y9-$y3)*($y2-$y1)/($y4-$y3) - $y1;
    my $denom = $x9 - ($x9-$x3)*($x2-$x1)/($x4-$x3) - $x1;
    my $m1 = $denom != 0 ? $num/$denom : undef;
    my $b1 = defined $m1 ? $y9 - $m1*$x9 : undef;
    my $m2 = ($y2 - $y1)/($x2-$x1);
    my $b2 = $y1 - $m2*$x1;
    my $x7 = ($y9 == $y1 || ! defined $m1) ? 0 : ($b2-$b1)/($m1-$m2);
    my $f1 = ($x7-$x1)/($x2-$x1);
    my $x_float = $f1*($self->{cols}-1);
    my $x_coord = $x_float < -.5 ? -1
                : $x_float > $self->{cols}-.5 ? -1
                : round($x_float);

    #locate y coord
    $num   = $y9 - ($y9-$y2)*($y3-$y1)/($y4-$y2) - $y1;
    $denom = ($x2 == $x4) ? $x9 - $x3
        : $x9 - ($x9-$x4)*($x1-$x3)/($x2-$x4) - $x3;
    $m1 = $denom != 0 ? $num/$denom : undef;
    $b1 = defined $m1 ? $y9 - $m1*$x9 : undef;
    $m2 = $x3 == $x1 ? undef : ($y3 - $y1)/($x3-$x1);
    $b2 = defined $m2 ? $y1 - $m2*$x1 : undef;
    my $y5 = (! defined $m1 || ! defined $m2) ? 0 : ($m2*$b1 - $m1*$b2)/($m2-$m1);
    $f1 = ($y5-$y1)/($y3-$y1);
    my $y_float = $f1*($self->{rows}-1);
    my $y_coord = $y_float < -.5 ? -1
                : $y_float > $self->{rows}-.5 ? -1
                : round($y_float);

    return undef if ($x_coord < 0 || $y_coord < 0);
    return [$x_coord,$y_coord];
}

sub round {
    my ($val,$places) = @_;
    $places = $places // 0;
    return (int($val*10**$places+0.5))/10**$places;
}

sub highlight {

    my ($self,@coords) = @_;
    my $w = $self->{pixbuf}->get_width;
    my $h = $self->{pixbuf}->get_height;
    my $surface = Cairo::ImageSurface->create('argb32',$w,$h);
    my $cr = Cairo::Context->create($surface);
    $cr->save;
    $cr->set_source_rgba(0.0, 1.0, 0.0, 0.2);
    $cr->set_line_width(1);
    for my $pixel (@coords) {
        my ($x,$y) = ($pixel->[0],$pixel->[1]);
        my ($w,$h) = (1,1);
        $cr->rectangle($x,$y,$w,$h);
    }
    $cr->fill;
    $cr->restore;
    $self->{hilite} = $surface;

}

sub FINALIZE_INSTANCE {

	my $self = shift;

}

1;
