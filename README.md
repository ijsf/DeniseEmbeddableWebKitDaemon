# LaunchDaemon

Open LaunchDaemon.xcodeproj, this project contains both the LaunchDaemonApp and LaunchDaemon.

## Installation

Whenever LaunchDaemonApp is built, a post script (Run Script in Targets -> LaunchDaemonApp -> Build Phases) is automatically executed that bundles all LaunchDaemon dynamic dylibs into a single app and installs this bundled LaunchDaemon app as daemon on the system in `/Library/PrivilegedHelperTools`.

This post-action requires that your current user is part of the no password sudoers file!

## Start and stop

Two options:

1. The LaunchDaemon can be manually started and stopped by using the appropriate scripts in the `Scripts` directory.
2. The LaunchDaemon can be started and stopped from XCode by using the Run function. This works using XCode shell scripts found in the Edit Schemes window.

## Logging

Debugging logs should be available at the following locations:

```
/tmp/denise_out.log (stdout)
/tmp/denise_error.log (stderr)
```
