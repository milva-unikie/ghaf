# SPDX-FileCopyrightText: 2022-2026 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
{ config, lib, ... }:
let
  cfg = config.ghaf.profiles.release;
  inherit (lib) mkEnableOption mkIf;
in
{
  _file = ./release.nix;

  options.ghaf.profiles.release = {
    enable = (mkEnableOption "release profile") // {
      default = false;
    };
  };

  config = mkIf cfg.enable {
    # Enable minimal profile as base
    ghaf.profiles.minimal.enable = true;

    # nix-setup.nixpkgs = null only clears nix.nixPath. The registry entry is
    # written by the upstream nixpkgs-flake module, and it is what actually
    # keeps the nixpkgs source tree in the runtime closure.
    nixpkgs.flake = {
      setFlakeRegistry = false;
      setNixPath = false;
    };

    # TODO(release-policy): turn this warning into an assertion once the
    # release credential policy and CI provisioning are agreed.
    # The condition has to include initialPassword: that is where the
    # well-known default actually lives (modules/common/users/admin.nix), so
    # testing only the hashed options would fire at anyone who set a real
    # password there and teach them to ignore the warning.
    warnings =
      lib.optional
        (
          config.ghaf.users.admin.enable
          && config.ghaf.users.admin.hashedPassword == null
          && config.ghaf.users.admin.initialHashedPassword == null
          && config.ghaf.users.admin.initialPassword == "ghaf"
        )
        "Release image ships the well-known default admin password. Set ghaf.users.admin.hashedPassword (e.g. mkpasswd -m yescrypt) for production images.";

    # Enable default accounts and passwords
    # TODO this needs to be refined when we define a policy for the
    # processes and the UID/groups that should be enabled by default
    # if not already covered by systemd
    # ghaf.users.admin.enable = true;
    ghaf = {
      # TODO we should move the nix-setup out of the development namespace
      development = {
        nix-setup = {
          enable = true;
          # Keep nix functional in release but do not pin the full nixpkgs
          # source tree into the closure (registry/nixPath are a debug aid).
          # mkOverride 90 rather than mkForce: this only needs to beat the
          # plain definition in modules/development/flake-module.nix, and
          # leaves mkForce available to a downstream that wants the pin back.
          nixpkgs = lib.mkOverride 90 null;
        };
      };

    };
  };
}
