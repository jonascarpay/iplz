{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs:
    let
      system = "x86_64-linux";
      pkgs = import inputs.nixpkgs { inherit system; };

      # Step 1. Write application
      iplz-lib = pkgs.python3Packages.buildPythonPackage {
        name = "iplz";
        src = ./app;
        propagatedBuildInputs = [ pkgs.python3Packages.falcon ];
      };

      iplz-server = pkgs.writeShellApplication {
        name = "iplz-server";
        runtimeInputs = [ (pkgs.python3.withPackages (p: [ p.uvicorn iplz-lib ])) ];
        text = ''
          uvicorn iplz:app "$@"
        '';
      };

      # Step 2: Define image
      bootstrap-config-module = {
        system.stateVersion = "22.05";
        services.openssh.enable = true;
        users.users.root.openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK0HDZvHZMdLOIFTrLF4UhSS4iwmsT3b3oBzWkWVHrNg"
        ];
      };

      live-config-module = {
        networking.firewall.allowedTCPPorts = [ 80 ];
        systemd.services.iplz = {
          enable = true;
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          script = ''
            ${iplz-server}/bin/iplz-server --host 0.0.0.0 --port 80
          '';
          serviceConfig = {
            Restart = "always";
            Type = "simple";
          };
        };
      };

      iplz-vm = inputs.nixos-generators.nixosGenerate {
        inherit pkgs;
        format = "vm";
        modules = [
          bootstrap-config-module
          {
            services.getty.autologinUser = "root";
            virtualisation.forwardPorts = [{ from = "host"; host.port = 8000; guest.port = 80; }];
          }
          live-config-module
        ];
      };

      # Step 3: Deploy
      bootstrap-img-name = "nixos-bootstrap-${system}";
      bootstrap-img = inputs.nixos-generators.nixosGenerate {
        inherit pkgs;
        format = "amazon";
        modules = [
          bootstrap-config-module
          { amazonImage.name = bootstrap-img-name; }
        ];
      };

      live-config = (inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          bootstrap-config-module
          live-config-module
          "${inputs.nixpkgs}/nixos/modules/virtualisation/amazon-image.nix"
        ];
      }).config.system.build.toplevel;
      bootstrap-img-path = "${bootstrap-img}/${bootstrap-img-name}.vhd";

      deploy-shell = pkgs.mkShell {
        packages = [ pkgs.terraform ];
        TF_VAR_bootstrap_img_path = bootstrap-img-path;
        TF_VAR_live_config_path = "${live-config}";
      };

      terraform = pkgs.writeShellScriptBin "terraform" ''
        export TF_VAR_bootstrap_img_path="${bootstrap-img-path}"
        export TF_VAR_live_config_path="${live-config}"
        ${pkgs.terraform}/bin/terraform $@
      '';

    in
    {
      packages.${system} = {
        inherit
          iplz-server
          iplz-vm
          bootstrap-img
          terraform;
      };
      devShell.${system} = deploy-shell;
    };
}
