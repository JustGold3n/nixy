{birdtray}:
birdtray.overrideAttrs (old: {
  patches = (old.patches or []) ++ [./birdtray-xwayland.patch];
})
