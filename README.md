# heli_telem_display

Heli Telem. Display - Full Screen Telemetry Display for Electric Helicopters - JETI

Compatible with DS-12, DS-24, DS-14 II, DS-16 II and corresponding DC models.

By Nick Pedersen (username "nickthenorse" on RCGroups.com and HeliFreak.com).

	v1.00 - 2021-08-14 - Initial release
	v1.01 - 2021-08-15 - Bug fix
	v1.02 - 2021-08-15 - Bug fix
	
Instructions: download the file HeliTelm.lua and copy it to the /Apps folder on your Jeti transmitter. Then install via "User Applications" submenu.

Thanks for trying out my Jeti Lua app! This is my attempt at learning Lua as well as 
putting together an app for how I specifically wanted to display the telemetry for my
FBL-based helicopters. It is based on my use of the Brain2 FBL, but will work well with
any modern FBL controller. The one caveat is that it is very much dependent on having
current and capacity sensing from the ESC.

![Screenshot Main Window](screenshot_main_window.png?raw=true "Screenshot Main Window")

![Screenshot Main Window, not fully charged lipo detected at startup](screenshot_not_fully_charged_lipo_at_startup.png?raw=true "Screenshot Main Window, not fully charged lipo detected at startup")

![Screenshot menu - Defaults](screenshot_menu_defaults.png?raw=true "Screenshot Menu - Defaults")

![Screenshot menu - Example of My Setup](screenshot_menu_example_setup.png?raw=true "Screenshot Menu - Example of my Setup")

 
It is a full screen telemetry window, and is hardcoded to display:

	- A flight timer (counts upwards only).
	
	- Rx telemetry: Instantaneous and mininum values for Q, A1, A2, and Rx voltage 
	  (max/min recorded for voltage). Signal levels also shown graphically.
	  
	- Maximum recorded FBL rotation rates for the elevator, aileron and rudder channels 
	  for the flight.
	  
	- Headspeed (instantaneous and maximum).
	
	- Lipo capacity used, in both percentage and in mAh. Capacity used also shown graphically
	  with a battery symbol. Total flight capacity of the lipo is assumed to be 80% of the 
	  nominal lipo capacity (ie, 80% of a 3700 mAh lipo = 2960 mAh).
	  
	- Custom selectable voice file/alarm levels for battery capacity used during the flight.
	
	- Custom selectable estimation of used battery capacity based on voltage, if the Rx is
	  powered up with a lipo that is not fully charged. Can also warn via audible voice file.
	  
	- The instantaneous and maximum values for ESC current, ESC temperature, ESC 
	  throttle/power, and FBL vibration level.
	  
	- Main flight pack voltage per cell (just the total lipo voltage divided by the
	  number of cells), as well as the min and max values recorded during the flight.
	  Min and max voltages shown graphically.
	  
	- Custom defineable voltage correction factor/multiplier - most ESCs do not allow you to tweak 
	  the voltage reading in case it is a few percent inaccurate.
	  
	- This main flight pack voltage per cell is also recorded as a custom variable in the
	  Jeti flight logs.
	  
	- Allows user to define a time delay to allow for FBL initialisation. Typically need ca. 10 seconds.
	
	- Allows user to specify number of samples to average voltage readings.
	
	- The app will detect when a new lipo is plugged in and automatically reset the flight timer and telemetry values,
	  though this can also be done manually by defining the appropriate switches in the menu.
	  
This is purely for my own hobbyist and non-commercial use.	No liability or responsibility 
is assumed for your own use! Feel free to use this code in any way you see fit to modify 
and/or personalise the telemetry that is being displayed, or as a way to learn lua for yourself.

Also: this is my first attempt at a lua app for Jeti. I can't claim it is particularly
efficiently coded, and is in no way optimised for optimal memory usage. But it works :)

Code heavily inspired by JETI model s.r.o.'s own lua application samples, as well as:

	- Tero excellent collection of lua "Jeti Tools" https://www.rc-thoughts.com/
	- Thorn's "Display" app from https://www.jetiforum.de/ and https://www.thorn-klaus-jeti.de
	- Dit71's "dbdis" app from https://www.jetiforum.de/ and https://github.com/ribid1/dbdis
