#!/bin/sh

PROJECT_DIR=$1
BUILT_PRODUCTS_DIR=$2
APP_BUNDLE_NAME=com.denise.daemon.app
APP_BUNDLE_EXECUTABLE=com.denise.daemon
PLIST_NAME=com.denise.daemon.plist

# Copy the daemon's launchd.plist into /Library/LaunchDaemons
for plist in daemon-Launchd.plist
do
  trg=/Library/LaunchDaemons/${PLIST_NAME}
  cp ${PROJECT_DIR}/LaunchDaemon/${plist} ${trg}
  chown root:wheel ${trg}
  chmod 644 ${trg}
done

echo *** Cleaning up

rm -rf /Library/PrivilegedHelperTools/${APP_BUNDLE_NAME}

echo *** Installing ${BUILT_PRODUCTS_DIR}/${APP_BUNDLE_NAME} to /Library/PrivilegedHelperTools

# Copy the daemon into /Library/PrivilegedHelperTools
cp -rf ${BUILT_PRODUCTS_DIR}/${APP_BUNDLE_NAME} /Library/PrivilegedHelperTools || exit 1
chown -R root:admin /Library/PrivilegedHelperTools/${APP_BUNDLE_NAME} || exit 1
