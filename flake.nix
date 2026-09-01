{
  # description = "";
  outputs = inputs @ {...}: {
    flakeModule = ./pdf.nix;
  };
}
