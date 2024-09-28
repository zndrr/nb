# Netbox Install Script

This set of bash scripts is an ongoing effort to streamline the Netbox install experience. \
Mostly a labour of love and a great learning experience.

It is intended to be highly defensive with a lot of detection and failsafes.
Not perfect of course. Still improving it.

The script intended to have as little interaction as possible:
- Developed in bash on Ubuntu
- Install type prompt
- Continue prompts between sections or at critical junctions
- Choosing a root user

To run, you can do one of two things:
- pull the git repo, or-
- wget the dl.sh (this however removes the continue prompts which expedites the install script).


It does automatically choose a DB and Secret pass though. This has security implications of course.

I'm sure there is a better way to do a lot of things.
Truth be told, I have already refactored many times as I have learned better approaches through my journey.
Never ends.

If you're here and have any suggestions or improvements, I would love to hear from you.


Zndrr
