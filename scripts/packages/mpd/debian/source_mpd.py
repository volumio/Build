'''
apport package hook for Music Player Deamon

Author: Ronny Cardona <rcart19@gmail.com>

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 2 of the License, or (at your
option) any later version.  See http://www.gnu.org/copyleft/gpl.html for
the full text of the license.
'''

from apport.hookutils import *
import os

# Reference for this function: http://pastebin.ubuntu.com/263396/
def _my_files(report, filename, keyname):
    if not (os.path.exists(filename)):
            return
    key = keyname 
    report[key] = ""
    for line in read_file(filename).split('\n'):
        try:
            if 'password' in line.split('"')[0]:
                line = "%s \"@@APPORTREPLACED@@\" " % (line.split('"')[0])
            report[key] += line + '\n'
        except IndexError:
            continue

def add_info(report):
       _my_files(report, os.path.expanduser('~/.mpdconf'), 'UserMpdConf')
