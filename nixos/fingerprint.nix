# Fingerprint authentication for local PAM prompts. pam_fprintd is added as a
# "sufficient" method before password authentication, so a failed or unavailable
# fingerprint reader still falls back to the user's password.
{...}: {
  services.fprintd.enable = true;

  # Fingerprints enrolled with fprintd-enroll must survive root filesystem wipes.
  environment.persistence."/persist".directories = [
    "/var/lib/fprint"
  ];
}
