#!/usr/bin/env fish
set bin_path (swift build --show-bin-path | tail -n 1)
set exe "JustDooooooIt"

set exe_path (swift build --show-bin-path | grep '^/' | tail -n 1)

if not test -x $exe_path
  echo "JUSTTTT FIND ITTTTT"
  exit 1
end

mv -f $exe_path ~/.local/bin/jdi
