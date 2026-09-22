package engine

/*
	 TODO: finish

	 The issue is that the stream handlers are hard to get and lockdown.

	 Audio manager to handle audio switching and queuing.
	 - fade in and out for long form
	 - it should have a main track
	 - next main track to switch
	 - push track
	 - replace track
*/


AudioManager :: struct {
	main_track: string,
	next_track: string,
}
