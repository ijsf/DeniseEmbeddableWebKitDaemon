#!/bin/sh

# Unload the daemon
launchctl unload /Library/LaunchDaemons/com.denise.daemon.plist

# Remove the daemon's launchd.plist
rm /Library/LaunchDaemons/com.denise.daemon.plist

# Remove the daemon's executable
rm -rf /Library/PrivilegedHelperTools/com.denise.daemon.app
