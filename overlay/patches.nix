final: prev: {
  python312Packages =
    prev.python312Packages
    // {
      patool = prev.python312Packages.patool.overrideAttrs (_: _: {
        doCheck = false;
        doInstallCheck = false;
      });
    };

  llm-agents =
    prev.llm-agents
    // {
      workmux = let
        src = prev.fetchFromGitHub {
          owner = "Fryuni";
          repo = "workmux";
          rev = "cf680ad8fe756ded5544619b2b14ab0dfab7958d";
          hash = "sha256-NFeyx2kAuckebQgjKh9qAKfTFG17SszJBQr686RO9mg=";
        };
      in
        prev.llm-agents.workmux.overrideAttrs (_: {
          inherit src;
          version = "0.1.117";
          patches = [];
          cargoDeps = prev.rustPlatform.fetchCargoVendor {
            inherit src;
            name = "workmux-vendor";
            hash = "sha256-8BxkjePCNwX39J74lTylGzVUAnNLNtMlYy6qwkO7eHY=";
          };
        });
    };
}
