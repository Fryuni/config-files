# DO NOT EDIT! This file is generated automatically by update.sh
{
  bootimage = {
    crateSha256 = "sha256-4WEpNrrGqmkyKbRRLmTe7Z7GnXyk635sniTfn99wN+g=";
    depsSha256 = "sha256-XXiZ0qfAS+SXOsiRAU/xBDShpPOr18JSGQfLh3mNXQ4=";
    description = "Tool to create a bootable OS image from a kernel binary.";
    homepage = null;
    id = "bootimage";
    keywords = [];
    owners = [
      {
        avatar = "https://avatars.githubusercontent.com/u/1131315?v=4";
        email = null;
        id = 880;
        kind = "user";
        login = "phil-opp";
        name = "Philipp Oppermann";
        url = "https://github.com/phil-opp";
      }
    ];
    version = "0.10.3";
  };
  cargo-cache = {
    crateSha256 = "sha256-aJoT3jIVpbs4GKiBHcApXTVY4EB11jyjcligV/IdQik=";
    depsSha256 = "sha256-275QREIcncgBk4ah/CivSz5N2m6s/XPCfp6JGChpr38=";
    description = "Manage cargo cache ($CARGO_HOME or ~/.cargo/), show sizes and remove directories selectively";
    homepage = "https://github.com/matthiaskrgr/cargo-cache";
    id = "cargo-cache";
    keywords = ["cargo" "cache" "cli" "cargo-home" "manage"];
    owners = [
      {
        avatar = "https://avatars.githubusercontent.com/u/476013?v=4";
        email = null;
        id = 13080;
        kind = "user";
        login = "matthiaskrgr";
        name = "Matthias Krüger";
        url = "https://github.com/matthiaskrgr";
      }
    ];
    version = "0.8.3";
  };
  cargo-crate = {
    crateSha256 = "sha256-n8iFtGA86GTe7j6ZQ7JRrUHTu998XdajjXIWy/fyg5w=";
    depsSha256 = "sha256-fKwMe4cE6C2q6RYcxiAB/E4XkHH253qLenrXmNmEdLc=";
    description = "A set of crate related cargo commands. You can for instance get the information about a crate, as text or json, including the owners of a crate and its versions.";
    homepage = "https://github.com/chevdor/cargo-crate";
    id = "cargo-crate";
    keywords = ["cargo" "cli" "cargo-subcommand" "crate"];
    owners = [
      {
        avatar = "https://avatars.githubusercontent.com/u/738724?v=4";
        email = null;
        id = 25136;
        kind = "user";
        login = "chevdor";
        name = "Chevdor";
        url = "https://github.com/chevdor";
      }
    ];
    version = "0.1.8";
  };
  cargo-docs = {
    crateSha256 = "sha256-OxI+8JqSD6AoHx8AjRbWpXwIS/ER1U0vOqr2tFlNq4M=";
    depsSha256 = "sha256-tf/exlEHYar6IpUk7fJwrx4eo98uk4lE6W7J/7HyUp8=";
    description = "A cargo plugin for serving rust and crate doc locally.";
    homepage = null;
    id = "cargo-docs";
    keywords = [];
    version = "0.1.24";
  };
  cargo-edit = {
    crateSha256 = "sha256-8QH1aud8IdPAhmZbk9hpDAOzubY2KG00Iw0D8T/vOZE=";
    depsSha256 = "sha256-8pymmsZeV+1tujlm5nzkXMS72vHFPJN0M50MVnyo7uo=";
    description = "Cargo commands for modifying a `Cargo.toml` file..";
    homepage = "https://github.com/killercup/cargo-edit";
    id = "cargo-edit";
    keywords = ["cargo-subcommand" "dependencies" "cli" "crates" "cargo"];
    owners = [
      {
        avatar = "https://avatars.githubusercontent.com/u/20063?v=4";
        email = null;
        id = 58;
        kind = "user";
        login = "killercup";
        name = "Pascal Hertleif";
        url = "https://github.com/killercup";
      }
      {
        avatar = "https://avatars.githubusercontent.com/u/60961?v=4";
        email = null;
        id = 6743;
        kind = "user";
        login = "epage";
        name = "Ed Page";
        url = "https://github.com/epage";
      }
      {
        avatar = "https://avatars3.githubusercontent.com/u/15256121?v=4";
        email = null;
        id = 7026;
        kind = "user";
        login = "bjgill";
        name = "Benjamin Gill";
        url = "https://github.com/bjgill";
      }
      {
        avatar = "https://avatars.githubusercontent.com/u/4211399?v=4";
        email = null;
        id = 7434;
        kind = "user";
        login = "ordian";
        name = null;
        url = "https://github.com/ordian";
      }
    ];
    version = "0.11.9";
  };
  cargo-expand = {
    crateSha256 = "sha256-Y+3htWT1tTTMzwRkQEX5MqMh9FBgFZ/Qn5/2mswuVBg=";
    depsSha256 = "sha256-umEbHzt2IqTkAAlzGmvHfyrSvbzT1crtQMkpaOw4s6U=";
    description = "Wrapper around rustc -Zunpretty=expanded. Shows the result of macro expansion and #[derive] expansion.";
    homepage = null;
    id = "cargo-expand";
    keywords = ["cargo" "subcommand" "macros"];
    owners = [
      {
        avatar = "https://avatars.githubusercontent.com/u/1940490?v=4";
        email = null;
        id = 3618;
        kind = "user";
        login = "dtolnay";
        name = "David Tolnay";
        url = "https://github.com/dtolnay";
      }
    ];
    version = "1.0.40";
  };
  cargo-lock = {
    crateSha256 = "sha256-Xh39gaiTC3g1FHVWqUr8PR/MzeoRaGlCmGZZZnHB4Kc=";
    depsSha256 = "sha256-gf9KDzGKjZt4p5ldZShH4lOwrieJeI2WJQ8hU4hhGJE=";
    description = "Self-contained Cargo.lock parser with optional dependency graph analysis";
    documentation = null;
    homepage = "https://rustsec.org";
    id = "cargo-lock";
    keywords = ["dependency" "cargo" "lock" "lockfile"];
    version = "8.0.3";
  };
  cargo-public-api = {
    crateSha256 = "sha256-s5aPzaH08XvGm+hZy+dQkvp8rVFcGWoTgniIfOzQk4E=";
    depsSha256 = "sha256-q5Oq9Lg7cNteHvzaAWwzoHThYiXac/x1Y5LyFZjfSCo=";
    description = "List and diff the public API of Rust library crates between releases and commits. Detect breaking API changes and semver violations via CI or a CLI.";
    homepage = "https://github.com/Enselic/cargo-public-api";
    id = "cargo-public-api";
    keywords = [];
    owners = [
      {
        avatar = "https://avatars.githubusercontent.com/u/1502855?v=4";
        email = null;
        id = 5417;
        kind = "user";
        login = "Emilgardis";
        name = "Emil Gardström";
        url = "https://github.com/Emilgardis";
      }
      {
        avatar = "https://avatars.githubusercontent.com/u/115040?v=4";
        email = null;
        id = 107610;
        kind = "user";
        login = "Enselic";
        name = "Martin Nordholts";
        url = "https://github.com/Enselic";
      }
      {
        avatar = "https://avatars.githubusercontent.com/u/102732092?v=4";
        email = null;
        id = 5657;
        kind = "team";
        login = "github:cargo-public-api:owners";
        name = "owners";
        url = "https://github.com/cargo-public-api";
      }
    ];
    version = "0.27.3";
  };
  cargo-sort = {
    crateSha256 = "sha256-i3Skc3Pc/3SxVCcLdMdxYVpkZZAZ0iew5UUq2tPVae8=";
    depsSha256 = "sha256-JON6cE1ZHeI+0vU9AJp0e1TIbiH3AWjHyn0jd9PNqQU=";
    description = "Check if tables and items in a .toml file are lexically sorted";
    homepage = null;
    id = "cargo-sort";
    keywords = ["dependencies" "sort" "subcommand" "check" "cargo"];
    owners = [
      {
        avatar = "https://avatars.githubusercontent.com/u/29749111?v=4";
        email = null;
        id = 12867;
        kind = "user";
        login = "DevinR528";
        name = "Devin Ragotzy";
        url = "https://github.com/DevinR528";
      }
    ];
    version = "1.0.9";
  };
  cargo-watch = {
    crateSha256 = "sha256-q1UAqVGWJNvcmIXqDYRNGuRgfdYeBTzNt1IclGEdEs4=";
    depsSha256 = "sha256-BzcKWQSB94H3XOsbwNvJoAHlZwkJvLABIrfFh9Ugfig=";
    description = "Watches over your Cargo project’s source";
    homepage = "https://watchexec.github.io/#cargo-watch";
    id = "cargo-watch";
    keywords = ["watch" "notify" "cargo" "compile"];
    owners = [
      {
        avatar = "https://avatars.githubusercontent.com/u/155787?v=4";
        email = null;
        id = 411;
        kind = "user";
        login = "passcod";
        name = "Félix Saparelli";
        url = "https://github.com/passcod";
      }
      {
        avatar = "https://avatars.githubusercontent.com/u/38887296?v=4";
        email = null;
        id = 362;
        kind = "team";
        login = "github:rust-bus:maintainers";
        name = "maintainers";
        url = "https://github.com/rust-bus";
      }
    ];
    version = "8.4.0";
  };
  prr = {
    crateSha256 = "sha256-HwChF+977k93uAEc+x6AgXNc3AH3NPsH4dq/JorwhJ0=";
    depsSha256 = "sha256-7f4tRhMFRVNUff2dcUnoxmzfkxjIENGCDyuSXzNRqHw=";
    description = "Mailing list style code reviews for github";
    homepage = null;
    id = "prr";
    keywords = [];
    version = "0.8.0";
  };
  toml-merge = {
    crateSha256 = "sha256-0rB/6XpZSFEdBPTa6nt/EFSPncQso+w8syXHUYoYfaA=";
    depsSha256 = "sha256-bNZzXLgXF9GWzl8yThZxUZKR/US1Gbgq7Yc3iVFcMtY=";
    description = "Simple CLI utility which merges TOML files.";
    homepage = null;
    id = "toml-merge";
    keywords = [];
    version = "0.1.0";
  };
  zellij = {
    crateSha256 = "sha256-X8NEHVI06VV1t+yEdZMvhg/1V44CpqoXVbbDY5Pku3s=";
    depsSha256 = "sha256-zk8/cUsr1UZMUYaYusTAChJkROZlRk0wJdwk1daSk+w=";
    description = "A terminal workspace with batteries included";
    documentation = null;
    homepage = "https://zellij.dev";
    id = "zellij";
    keywords = [];
    owners = [
      {
        avatar = "https://avatars.githubusercontent.com/u/6251883?v=4";
        email = null;
        id = 6277;
        kind = "user";
        login = "TheLostLambda";
        name = "Brooks Rady";
        url = "https://github.com/TheLostLambda";
      }
      {
        avatar = "https://avatars.githubusercontent.com/u/1002622?v=4";
        email = null;
        id = 35784;
        kind = "user";
        login = "qballer";
        name = "Doron Tsur";
        url = "https://github.com/qballer";
      }
      {
        avatar = "https://avatars.githubusercontent.com/u/795598?v=4";
        email = null;
        id = 64017;
        kind = "user";
        login = "imsnif";
        name = "Aram Drevekenin";
        url = "https://github.com/imsnif";
      }
      {
        avatar = "https://avatars.githubusercontent.com/u/71698300?v=4";
        email = null;
        id = 101386;
        kind = "user";
        login = "henil";
        name = "Henil Dedania";
        url = "https://github.com/henil";
      }
      {
        avatar = "https://avatars.githubusercontent.com/u/99636919?v=4";
        email = null;
        id = 173084;
        kind = "user";
        login = "har7an";
        name = null;
        url = "https://github.com/har7an";
      }
    ];
    version = "0.35.2";
  };
}
