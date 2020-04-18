# EmbeddableWebKitDaemon

This is an example daemon service that embeds the EmbeddableWebKit component and provides a XPC service to which clients can talk.

This example was made to show that certain constrained macOS applications (such as VST plugins) can also make use of an embedded browser simply by talking to an XPC service. Also look at the DeniseEmbeddeableWebKit and DeniseEmbeddableWebKitXPCApp for more information. This code was developed for a prototype that is no longer functional, and is therefore open sourced.

This repository is currently unmaintained.

---

Open LaunchDaemon.xcodeproj, this project contains both the LaunchDaemonApp and LaunchDaemon.

## Installation

Whenever LaunchDaemonApp is built, a post script (Run Script in Targets -> LaunchDaemonApp -> Build Phases) is automatically executed that bundles all LaunchDaemon dynamic dylibs into a single app and installs this bundled LaunchDaemon app as daemon on the system in `/Library/PrivilegedHelperTools`.

This post-action requires that your current user is part of the no password sudoers file!

## Errors

If any errors occur, head over to the `webkitgtk_denise` repository and read the documentation. 

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
