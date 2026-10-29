{xdg-desktop-portal-termfilechooser}:
xdg-desktop-portal-termfilechooser.overrideAttrs (old: {
  # An empty selection is cancellation, not a D-Bus AccessDenied error.
  patches =
    (old.patches or [])
    ++ [
      ./termfilechooser-cancel.patch
      ./termfilechooser-private-output.patch
    ];
})
