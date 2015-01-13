#!/usr/bin/perl

#
# scribe.pl
#
# Scribe is a logging bot designed for recording D&D games. It will auto-join
# channels it has been invited to and leave channels when they are empty. 
# You can assign one home channel that scribe will never leave.
#

use POE qw(Component::IRC);
use POE::Component::IRC::Plugin::Logger;
use POE::Component::IRC::State;

use strict;
use warnings;

my $nick = 'scribe';
my $user = 'scribe';
my $name = 'scribe';
my $serv = 'localhost';

my $home = ''; # permanent channel
my $logpath = ''; # place to store logs.

my $irc = POE::Component::IRC::State->spawn(
	nick => $nick,
	username => $user,
	ircname => $name,
	server => $serv);

$irc->plugin_add('Logger', POE::Component::IRC::Plugin::Logger->new(
	Path => $logpath,
	DCC => 0,
	Private => 0,
	Public => 1));

POE::Session->create(package_states => [ main => [qw(_start irc_001 irc_disconnected irc_invite irc_part irc_quit)] ],
	heap => { irc => $irc});

POE::Kernel->run();

sub bot_connect() {
	$irc->yield(connect => {nick => $nick, username => $user, ircname => $name, server => $serv});
}

sub _start {
	$irc->yield(register => 'all');
	bot_connect();
}

sub irc_001 {
	$irc->yield(join => $home);
}

sub irc_disconnected {
	bot_connect();
}

sub irc_invite {
	$irc->yield(join => $_[ARG1]);
}

sub should_leave {
	my $channel = pop;
	return 0 if $channel eq $home;
	my @users = $irc->channel_list($channel);
	return @users ~~ [$nick];
}

sub irc_part {
	my $channel = $_[ARG1];
	$irc->yield(part => $channel) if should_leave $channel;
}

sub irc_quit {
	my $channels = $_[ARG2];
	foreach (@$channels) {
		$irc->yield(part => $_) if should_leave $_;
	}
}
