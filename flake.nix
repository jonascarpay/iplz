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
      base-config = {
        system.stateVersion = "22.05";
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
          base-config
          {
            services.getty.autologinUser = "root";
            virtualisation.forwardPorts = [{ from = "host"; host.port = 8000; guest.port = 80; }];
          }
        ];
      };

      # Step 3: Deploy
      image-name = "iplz-${system}";
      iplz-ec2-img = inputs.nixos-generators.nixosGenerate {
        inherit pkgs;
        format = "amazon";
        modules = [
          base-config
          { amazonImage.name = image-name; }
        ];
      };
      iplz-img-path = "${iplz-ec2-img}/${image-name}.vhd";

      deploy-shell = pkgs.mkShell {
        packages = [ pkgs.terraform ];
        TF_VAR_iplz_img_path = iplz-img-path;
      };

      terraform = pkgs.writeShellScriptBin "terraform" ''
        export TF_VAR_iplz_img_path="${iplz-img-path}"
        ${pkgs.terraform}/bin/terraform $@
      '';

    in
    {
      packages.${system} = {
        inherit
          iplz-server
          iplz-vm
          iplz-ec2-img
          terraform;
      };
      devShell.${system} = deploy-shell;
    };
}
