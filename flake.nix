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
          export WRFKIT_SHELL=1
          export WRFKIT_WRF_VERSION="${wrfVersion}"
          export WRFKIT_WRF_ARCHIVE="${wrfArchive}"

          export CC=gcc
          export CXX=g++
          export FC=gfortran
          export F77=gfortran
          export F90=gfortran

          if [[ -n "''${WRFKIT_ROOT:-}" ]]; then
            # Make the wrfctl command itself available without ./ while this
            # shell is active.
            export PATH="$WRFKIT_ROOT:$PATH"

            wrfkit_bin="$WRFKIT_ROOT/.wrfkit/install/wrf-${wrfVersion}/bin"
            if [[ -d "$wrfkit_bin" ]]; then
              export PATH="$wrfkit_bin:$PATH"
            fi
            unset wrfkit_bin
          fi

          # Conda-style marker for interactive Bash prompts. Some prompt
          # frameworks rebuild PS1 before every prompt, so enforce the marker
          # from PROMPT_COMMAND instead of setting PS1 only once.
          # This is session-local; no user dotfiles are modified.
          if [[ $- == *i* ]]; then
            _wrfkit_prompt_marker() {
              if [[ "''${PS1:-}" != "(wrfkit) "* ]]; then
                PS1="(wrfkit) ''${PS1:-\\u@\\h:\\w\\$ }"
              fi
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
