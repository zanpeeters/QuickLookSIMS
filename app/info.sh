#!/bin/sh

#  fake.sh
#  QuickLookSIMS.app
#
#  Created by Zan Peeters on 22-02-2018.
#  Copyright © 2018 Zan Peeters. All rights reserved.

/usr/bin/osascript -e 'tell app "System Events" to display dialog "This application is part of QuickLookSIMS. It does nothing by itself, it exists only so that the Uniform Type Identifiers (UTIs) for SIMS.mdimporter get processed by macOS.\n\nPlease, DO NOT REMOVE!" with title "QuickLookSIMS" buttons "Exit" default button "Exit"'
