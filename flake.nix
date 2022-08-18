{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-22.05";
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs:
    let
      system = "x86_64-linux";
      pkgs = import inputs.nixpkgs { inherit system; };

      iplz_config = {
        documentation.man.enable = false;
        system.stateVersion = "22.05";
        networking.firewall.allowedTCPPorts = [ 80 ];
        services.nginx = {
          enable = true;
          virtualHosts."iplz" = {
            default = true;
            serverName = null;
            locations."/" = {
              return = ''
                200 $remote_addr\n
              '';
              extraConfig = ''
                add_header Content-Type text/plain;
              '';
            };
          };
        };
        users.mutableUsers = false;
        users.users.root.openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK0HDZvHZMdLOIFTrLF4UhSS4iwmsT3b3oBzWkWVHrNg"
        ];
        services.openssh = {
          enable = true;
          permitRootLogin = "prohibit-password";
        };
      };

    in
    {
      packages.${system} = {
        iplz-qemu = inputs.nixos-generators.nixosGenerate {
          inherit pkgs;
          format = "vm";
          modules = [
            iplz_config
            { virtualisation.forwardPorts = [{ from = "host"; host.port = 8000; guest.port = 80; }]; }
          ];
        };
        iplz-ami = inputs.nixos-generators.nixosGenerate {
          inherit pkgs;
          format = "amazon";
          modules = [ iplz_config ];
        };
      };
      devShell.${system} = pkgs.mkShell {
        packages = [
          pkgs.terraform
          pkgs.awscli2
        ];
      };
    };
}
