#!/home/pi/oprint/bin/python
# coding=utf-8
from __future__ import absolute_import

__author__ = "David Crook <dpcrook@users.noreply.github.com>"
__license__ = 'GNU Affero General Public License http://www.gnu.org/licenses/agpl.html'
__copyright__ = "Copyright (C) 2016 The OctoPrint Project - Released under terms of the AGPLv3 License"

# plugin_status.py - Script to determine if a plugin is enabled in OctoPrint

# Returns an exit code for shell script:
#  - 0: Plugin is enabled
#  - 1: Plugin is not enabled
# 
# USAGE
#
#   # check by default for 'touchui' plugin
#   plugin_status.py
#
#   # check for 'pluginmanager' plugin
#   plugin_status.py pluginmanager
#
#   # returns exit code of 1 for plugin not enabled
#   plugin_status.py nonexistent
#   echo $0
#

import sys

from octoprint.settings import settings
import octoprint.plugin

DEBUG = False
#DEBUG = True

# see if a command line argument was used
plugin_name = 'touchui'
if sys.argv[1:]:
    plugin_name = sys.argv[1]

# initialize settings object (required by plugin_manager)
s = settings(init=True, basedir=None, configfile=None)
pluginManager = octoprint.plugin.plugin_manager(init=True) 

if DEBUG:
    print pluginManager.enabled_plugins

if plugin_name in pluginManager.enabled_plugins:
    print "Plugin '" + plugin_name + "' found enabled"
    sys.exit(0)
else:
    print "Plugin '" + plugin_name + "' NOT found enabled"
    sys.exit(1)



# ======================================================================
# Some helpful files and commands I used to investigate
#
# OctoPrint/src/octoprint/server/__init__.py
# grep -R 'Server(' OctoPrint/src/octoprint
# OctoPrint/src/octoprint/__init__.py
# grep -R 'Main(' OctoPrint/src/octoprint

