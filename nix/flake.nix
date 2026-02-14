{
  description = "Fabric - GitOps NixOS Infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, ... }@inputs: {
    # NixOS configurations for each host
    nixosConfigurations = {
      # DNS server
      dns01 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/dns01/configuration.nix
          ./modules/base.nix
          ./modules/networking-static.nix
          ./modules/dns-unbound.nix
        ];
      };

      # Docker host
      docker01 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/docker01/configuration.nix
          ./modules/base.nix
          ./modules/networking-static.nix
          ./modules/docker-host.nix
        ];
      };

      # Test/example VM with minimal config
      test-vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/test-vm/configuration.nix
          ./modules/base.nix
        ];
      };
    };

    # Helper to add new hosts easily
    # Usage: Add new entry above following this pattern
  };
}
