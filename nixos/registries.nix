_:
{
  nix.registry = {
    node.to = {
      type = "github";
      owner = "andyrichardson";
      repo = "nix-node";
    };

    flake-utils.to = {
      type = "github";
      owner = "numtide";
      repo = "flake-utils";
    };
  };
}
