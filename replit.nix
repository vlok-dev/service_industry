{ pkgs }: {
  deps = [
    pkgs.ruby_3_3
    pkgs.bundler
    pkgs.sqlite
    pkgs.nodejs_20
    pkgs.yarn
    pkgs.libpq
    pkgs.postgresql
    pkgs.openssl
    pkgs.zlib
    pkgs.libffi
    pkgs.readline
    pkgs.bash
    pkgs.git
  ];
}