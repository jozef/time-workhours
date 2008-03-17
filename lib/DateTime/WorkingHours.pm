package DateTime::WorkingHours;

=head1 NAME

DateTime::WorkingHours - renamed to Time::WorkHours

=head1 DESCRIPTION

Don't use this one. Use L<Time::WorkHours> instead because:

	-------- Original Message --------
	Subject: Re: Your module DateTime::WorkingHours
	Date: Mon, 17 Mar 2008 09:53:56 +0100
	From: Jozef Kutej <jozef@kutej.net>
	To: Dave Rolsky <autarch@urth.org>
	CC: datetime@perl.org
	
	Dave Rolsky wrote:
	> On Fri, 14 Mar 2008, Jozef Kutej wrote:
	> 
	>>> I noticed you released a module DateTime::WorkingHours recently. I'd
	>>> prefer that folks not release modules under the DateTime namespace
	>>> without talking to the datetime@perl.org list about it first. In
	>>> particular, the namespace you've chosen doesn't really fit within the
	>>> DateTime namespace guidelines (see
	>>> http://datetime.perl.org/index.cgi?NamespaceStandards)
	>>
	>> Sorry, I didn't know. I got fast "inspiration" from
	>> DateTime::BusinessHours. But as I look now it doesn't have a log
	>> "history".
	> 
	> Heh, I contacted the author of that module too but he never replied.
	> 
	>>> Would you mind posting something to the datetime@perl.org list to
	>>> discuss both the name and API of your module? Alternately, if you don't
	>>> want to do that, I'd appreciate it if you'd rename the module so it
	>>> doesn't start with "DateTime::".
	>>
	>> I don't mind to think of any different name (inside or outside of
	>> DateTime::). What are the suggestions?
	> 
	> Well, if you want it in the DateTime:: namespace, we should discuss the
	> API first on the list. The key is to make sure that the API looks like
	> any similar modules.
	> 
	> In this particular case, I'm not sure there _are_ any similar modules,
	> which is all the more reason to get the API right this time, so that any
	> similar modules that come along later have a model to follow.
	> 
	
	I have renamed the module to Time::WorkHours.
	
	Regards,
	Jozef

=cut

use warnings;
use strict;

our $VERSION = '0.02';

use DateTime;
use Carp::Clan 'croak';

use base 'Class::Accessor::Fast';

=head1 PROPERTIES

    work_interval_start
    work_interval

=cut

__PACKAGE__->mk_accessors(qw{
    work_interval_start
    work_interval    
});


my $DAY_MINUTES = 24*60;


=head1 METHODS

=head2 new()

Object constructor. Pass two mandatory arguments. C<work_interval_start>
and C<work_interval>.

C<work_interval_start> is the minute (or hour) when the working hours
start.

C<work_interval> is how many minutes (or hours) does the working interval
last.

Both can be passed as a number in that case must represent minutes or as a string
with numbers and 'h' at the end representing the value in hours.

Example:

    $wh = DateTime::WorkingHours->new(
        work_interval_start => '2h',  # or 120
        work_interval       => 180,   # or '3h'
    );

Work interval starts at 02:00 and lasts for 3 hours.

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new({ @_ });
    
    croak 'pass work_interval_start'
        if not defined $self->work_interval_start;
    croak 'pass work_interval'
        if not defined $self->work_interval;
    
    return $self;
}


=head2 work_start($datetime)

Return nearest DateTime when the work time starts. If inside
the work interval then returns start datetime of this
interval.

If argument not passed the default is C<< DateTime->now >>.

=cut

sub work_start {
    my $self = shift;
    my $date = shift;
    
    # make a copy of passed DateTime
    if ($date) {
        $date = $date->clone();
    }
    else {
        $date = DateTime->now();
    }
    _strip_seconds($date);
    my $work_start = $date->clone;    

	my $work_interval_start  = $self->work_interval_start_minute;
	my $work_interval        = $self->work_interval_minutes;
	my $work_interval_end    = $work_interval_start + $work_interval;
    my $work_interval_shift += $DAY_MINUTES - $work_interval_end;

	$date->add('minutes' => $work_interval_shift);
    my $date_minutes = $date->hour*60 + $date->minute;
    
    $work_start->add('minutes' => $work_interval_start + $work_interval_shift - $date_minutes);
    
	return $work_start;
}


=head2 next_work_start($datetime)

Same as work_start but will always return DateTime in the
future.

=cut

sub next_work_start {
    my $self = shift;
    my $date = shift;
    
    my $work_start = $self->work_start($date);
    
    # shift by 24h if date is within working hours so the work_start is in the past
    $work_start->add('hours' => 24)
        if $work_start < $date;
    
    return $work_start;
}


=head2 work_end($datetime)

Returns nearest end of the work time.

If argument not passed the default is C<< DateTime->now >>.

=cut

sub work_end {
    my $self = shift;
    my $date = shift || DateTime->now;
    
    my $work_start    = $self->work_start($date);
    my $work_interval = $self->work_interval_minutes;

    return $work_start->add('minutes' => $work_interval);;
}


=head2 within($datetime)

Return true/false if the $datetime lies within working hours.

If argument not passed the default is C<< DateTime->now >>.

=cut

sub within {
    my $self = shift;
    my $date = shift || DateTime->now;
    
	my $work_start_datetime = $self->work_start($date);
	my $work_end_datetime   = $self->work_end($date);
	
	return 1
	    if (($date >= $work_start_datetime) and ($date < $work_end_datetime));
	return 0;
}


=head2 shift_to_working_time($date)

Takes the $date and moves it to the neares working time interval.
The shift is calculated proportionaly so that the time shifts are
distributed in the working hour interval in the same order as
they occure in 24h interval.

Example:

    my $wh = DateTime::WorkingHours->new(
        work_interval_start => '22h',
        work_interval       => '4h',
    );
    my $new_datetime = $wh->shift_to_working_time(DateTime->new(
        'day'    => 5,
        'hour'   => 14,
        'minute' => 00,
        # ... what ever month, year
    ));

Will shift to next day to 00:00 as 14:00 is just in the middle of 02:00 - (22:00) - 02:00
interval so it's shifted to the middle of 22:00 - 02:00 working hours.

If the DateTime will be at 01:59 (last minute of the working interval) there will be no shift.

If the DateTime will be at 02:00 (first non working minute) the shift will be to 22:00.

If argument not passed the default is C<< DateTime->now >>.

=cut

sub shift_to_working_time {
    my $self = shift;
    my $date = shift || DateTime->now;
    
    croak 'pass DataTime object as argument'
        if ref $date ne 'DateTime';
    
    $date = $date->clone;
    
	my $work_interval_start = $self->work_interval_start_minute;
	my $work_interval       = $self->work_interval_minutes;
	my $work_start          = $self->work_start($date);
	my $work_interval_end   = $work_interval_start + $work_interval;
	my $work_interval_shift = $DAY_MINUTES - $work_interval_end;	

	$date->add('minutes' => $work_interval_shift);
    my $date_minutes = $date->hour*60 + $date->minute;
	
	my $event_date = $work_start->add('minutes' => ($date_minutes / $DAY_MINUTES) * $work_interval);
	
	return $event_date;
}


=head2 work_interval_start_minute()

Return number of minute in the day when the work interval starts.

=cut

sub work_interval_start_minute {
    my $self = shift;
    my $work_interval_start = $self->work_interval_start;
    
    if ($work_interval_start =~ m/\b([0-9]+)h$/) {
        return $1*60;
    }
    else {
        return $work_interval_start;
    }
}


=head2 work_interval_minutes()

Return for how many minutes does the work interval lasts.

=cut

sub work_interval_minutes {
    my $self = shift;
    my $work_interval = $self->work_interval;
    
    if ($work_interval =~ m/\b([0-9]+)h$/) {
        return $1*60;
    }
    else {
        return $work_interval;
    }
}

sub _strip_seconds {
    my $date = shift;
	$date->add('seconds' => -$date->second);
	return $date;
}


'ROMERQUELLE(R)';


__END__

=head1 AUTHOR

Jozef Kutej

=head1 COPYRIGHT & LICENSE

Copyright 2008 Jozef Kutej, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
