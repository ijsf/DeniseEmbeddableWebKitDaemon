# LaunchDaemon

Open LaunchDaemon.xcodeproj, this project contains both the LaunchDaemonApp and LaunchDaemon.

## Installation

Whenever LaunchDaemonApp is built, a post-action (in dependency LaunchDaemon) is automatically executed that installs the LaunchDaemon as daemon on the system.

This post-action requires that your current user is part of the no password sudoers file!

## Start and stop

The LaunchDaemon can be manually started and stopped by using the appropriate scripts in the `Scripts` directory.

These scripts should also be invoked automatically whenever the LaunchDaemonApp is started or stopped from XCode.

## Logging

Debugging logs should be available at the following locations:

```
/tmp/denise_out.log (stdout)
/tmp/denise_error.log (stderr)
```
