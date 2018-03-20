#!/usr/bin/env bash
# https://thegreyblog.blogspot.com/2014/06/os-x-creating-packages-from-command_2.html

# Make sure we're in the right dir
cd ~/Documents/Devel/Mac/QuickLookSIMS/dist

# # Create component plists
pkgbuild --analyze --root qlroot ql_component.plist
pkgbuild --analyze --root mdroot md_component.plist
pkgbuild --analyze --root approot app_component.plist

# # Create component pkgs
pkgbuild --root qlroot --scripts qlscripts --component-plist ql_component.plist ql.pkg
pkgbuild --root mdroot --scripts mdscripts --component-plist md_component.plist md.pkg
pkgbuild --root approot --scripts appscripts --component-plist app_component.plist app.pkg

# Create requirements.plist
cat <<EOF > requirements.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>os</key>
  <array>
    <string>10.7</string>
  </array>
  <key>home</key>
  <true/>
</dict>
</plist>
EOF

# Create distribution.plist
productbuild --synthesize \
             --product requirements.plist \
             --package ql.pkg \
             --package md.pkg  \
             --package app.pkg \
             distribution.plist

# Add license and readme
sed -E -i '' -e '/<installer-gui-script/ a \
    <license file="LICENSE.md" /> \
    <readme file="README.md" /> \
' distribution.plist

# Create final package
productbuild --distribution distribution.plist --resources ../ QuickLookSIMS.pkg

# Clean up
rm *.plist ql.pkg md.pkg app.pkg
