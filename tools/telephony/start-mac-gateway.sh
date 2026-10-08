#!/bin/sh
set -eu
: "${AIS_TELEPHONY_VM_WRAPPER:?Set the absolute path to vm.sh}"
"$AIS_TELEPHONY_VM_WRAPPER" start p --tty=false
# Prevent idle system sleep while the phone gateway is running; display sleep
# remains available. This does not override a manual sleep/shutdown.
exec /usr/bin/caffeinate -i
