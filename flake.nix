{
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        ruby = pkgs.ruby_3_2.withPackages (ps: with ps; [ nokogiri ]);
      in
      {
        devShells.default =
          pkgs.mkShell {
            nativeBuildInputs = [ ruby pkgs.gnuplot ];
          };

        packages.default =
          pkgs.stdenv.mkDerivation {
            pname = "nom";
            version = "0.1.6";
            src = ./.;
            buildInputs = [ ruby pkgs.gnuplot ];
            installPhase = ''
              mkdir -p $out/{bin,share/nom}
              cp -r lib bin $out/share/nom
              bin=$out/bin/nom

              cat > $bin <<EOF
              #!/bin/sh -e
              export PATH="${pkgs.gnuplot}/bin:$PATH"
              exec ${ruby}/bin/ruby $out/share/nom/bin/nom "\$@"
              EOF

              chmod +x $bin
            '';
          };
      }
    );
}
