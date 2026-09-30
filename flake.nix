{
  description = "Reproducible WRF 4.8.0 development environment";

  # Pin nixpkgs by commit so the initial environment is reproducible even
  # before a flake.lock is committed.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/7fc6f2c20af09cdcaf48b92ec3121860139ec668";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      wrfVersion = "4.8.0";
      wrfArchive = pkgs.fetchurl {
        url = "https://github.com/wrf-model/WRF/releases/download/v${wrfVersion}/v${wrfVersion}.tar.gz";
        hash = "sha256-87mXJmN54XGdGGySRxqPRPgYXpdiRKveghRaf93q9Bg=";
      };
    in {
      packages.${system}.wrf-source = wrfArchive;

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          bashInteractive
          bison
          cacert
          cmake
          file
          flex
          gcc
          gfortran
          git
          gnumake
          libtirpc
          m4
          netcdf
          netcdffortran
          openmpi
          perl
          pkg-config
          which
          zlib
        ];

        shellHook = ''
          export WRFKIT_NIX_SHELL=1
          export WRFKIT_WRF_VERSION="${wrfVersion}"
          export WRFKIT_WRF_ARCHIVE="${wrfArchive}"

          export CC=gcc
          export CXX=g++
          export FC=gfortran
          export F77=gfortran
          export F90=gfortran
        '';
      };
    };
}
