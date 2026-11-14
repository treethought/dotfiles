#!/usr/bin/env bash
# Use suspend-to-RAM (S3) instead of s2idle when the system suspends.
#
# Why: on this Framework 13 (12th gen Intel) a long s2idle session leaves the
# embedded controller latched at 400 MHz on every core, and reboots do not
# clear it, only an EC power cycle does. s2idle keeps the SoC powered in S0, so
# a closed lid in a bag keeps making heat with the fan off, which is the
# suspected trigger. S3 powers the SoC down and leaves only RAM refreshing, so
# the suspended machine stays close to room temperature.
#
# This does not change what the desktop shows: DMS and niri still call
# logind's Suspend, and the kernel just uses S3 underneath. Hibernate is a
# separate thing and remains unavailable until this machine has disk swap.
#
# Run as root. The cmdline change persists across upgrades; the sysfs write
# applies to the next suspend without rebooting.
set -euo pipefail

if ! grep -qw deep /sys/power/mem_sleep; then
    echo "kernel does not advertise the 'deep' sleep state" >&2
    exit 1
fi

grubby --update-kernel=ALL --args=mem_sleep_default=deep
echo deep > /sys/power/mem_sleep

echo "mem_sleep:   $(cat /sys/power/mem_sleep)"
echo "boot args:   $(grubby --info=DEFAULT | sed -n 's/^args="\(.*\)"$/\1/p')"
echo "note:        /proc/cmdline only shows mem_sleep_default after a reboot"
