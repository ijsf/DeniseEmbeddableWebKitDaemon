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

# Fix bundle
#${PROJECT_DIR}/Scripts/bundle.sh ${PROJECT_DIR} ${BUILT_PRODUCTS_DIR}/${APP_BUNDLE_NAME} ${APP_BUNDLE_EXECUTABLE}

# Copy the daemon into /Library/PrivilegedHelperTools
cp -rf ${BUILT_PRODUCTS_DIR}/${APP_BUNDLE_NAME} /Library/PrivilegedHelperTools
chown -R root:admin /Library/PrivilegedHelperTools/${APP_BUNDLE_NAME}
