# Udiskie is a simple daemon that uses udisks to automatically mount removable storage devices.
{config, ...}: {
  services.udiskie = {
    enable = true;
    notify = (config.var.hostname or "") == "nixtop";
    automount = true;
    tray = "never";
  };
}
