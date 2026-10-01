{
  description = "Reproducible WRF 4.8.0 + WPS 4.7.0 development environment";

  # Pin nixpkgs by commit so the initial environment is reproducible even
  # before a flake.lock is committed.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/7fc6f2c20af09cdcaf48b92ec3121860139ec668";

  # WPS 4.7.0 release commit. Keep this as a non-flake source input; wrfkit
  # copies it into project-local state before building because WPS' bundled
  # GRIB2 externals are built in-place.
  inputs.wps = {
    url = "github:wrf-model/WPS/5feccecd63384381b6942371c7a837f66e4ccb84";
    flake = false;
  };

  outputs = { nixpkgs, wps, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      wrfVersion = "4.8.0";
      wrfArchive = pkgs.fetchurl {
        url = "https://github.com/wrf-model/WRF/releases/download/v${wrfVersion}/v${wrfVersion}.tar.gz";
        hash = "sha256-87mXJmN54XGdGGySRxqPRPgYXpdiRKveghRaf93q9Bg=";
      };

      wpsVersion = "4.7.0";
      wpsRevision = "5feccecd63384381b6942371c7a837f66e4ccb84";
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
          python3
          tcsh
          which
          zlib
        ];

        shellHook = ''
          export WRFKIT_NIX_SHELL=1
          export WRFKIT_SHELL=1

          export WRFKIT_WRF_VERSION="${wrfVersion}"
          export WRFKIT_WRF_ARCHIVE="${wrfArchive}"

          export WRFKIT_WPS_VERSION="${wpsVersion}"
          export WRFKIT_WPS_REV="${wpsRevision}"
          export WRFKIT_WPS_SOURCE="${wps}"

          export CC=gcc
          export CXX=g++
          export FC=gfortran
          export F77=gfortran
          export F90=gfortran

          if [[ -n "''${WRFKIT_ROOT:-}" ]]; then
            # Make wrfctl and installed WRF/WPS binaries available without ./
            # while this shell is active. The paths may not exist yet; keeping
            # them in PATH means binaries become visible after a build.
            export PATH="$WRFKIT_ROOT:$WRFKIT_ROOT/.wrfkit/install/wrf-${wrfVersion}/bin:$WRFKIT_ROOT/.wrfkit/install/wps-${wpsVersion}/bin:$PATH"
          fi

          # Conda-style marker for interactive Bash prompts. Some prompt
          # frameworks rebuild PS1 before every prompt, so enforce the marker
          # from PROMPT_COMMAND instead of setting PS1 only once.
          # This is session-local; no user dotfiles are modified.
          if [[ $- == *i* ]]; then
            _wrfkit_prompt_marker() {
              case "''${PS1:-}" in
                *"(wrfkit) "*) ;;
                *) PS1="''${PS1:-\u@\h:\w\$ }(wrfkit) " ;;
              esac
            }

            if declare -p PROMPT_COMMAND 2>/dev/null | grep -q '^declare -a'; then
              wrfkit_pc_present=0
              for wrfkit_pc in "''${PROMPT_COMMAND[@]}"; do
                [[ "$wrfkit_pc" == "_wrfkit_prompt_marker" ]] && wrfkit_pc_present=1
              done
              (( wrfkit_pc_present )) || PROMPT_COMMAND+=(_wrfkit_prompt_marker)
              unset wrfkit_pc wrfkit_pc_present
            else
              case ";''${PROMPT_COMMAND:-};" in
                *";_wrfkit_prompt_marker;"*) ;;
                *)
                  if [[ -n "''${PROMPT_COMMAND:-}" ]]; then
                    PROMPT_COMMAND="''${PROMPT_COMMAND%;};_wrfkit_prompt_marker"
                  else
                    PROMPT_COMMAND="_wrfkit_prompt_marker"
                  fi
                  ;;
              esac
            fi

            _wrfkit_prompt_marker
          fi
        '';
      };
    };
}
