#!/usr/bin/env fish

# Clean previous builds
rm -rf .build

# Build the project
swift build -c release 2>&1 | grep -v "no version information available"

set bin_path (swift build -c release --show-bin-path 2>/dev/null | tail -n 1)
set exe "JustDooooooIt"
set exe_path "$bin_path/$exe"

if not test -x $exe_path
  echo "Error: Could not find executable at $exe_path"
  exit 1
end

# Remove old binary and install new one
rm -f ~/bin/jdi
cp -f $exe_path ~/bin/jdi
chmod +x ~/bin/jdi
echo "Successfully installed jdi to ~/bin/jdi"
