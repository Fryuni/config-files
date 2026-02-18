# DO NOT EDIT! This file is generated automatically by update.mjs
{
  bootimage = {
    crateSha256 = "sha256-4WEpNrrGqmkyKbRRLmTe7Z7GnXyk635sniTfn99wN+g=";
    depsHash = "sha256-CkFJHW7yrIJi/KMGJgyhnLTMkrxnDwO3X4M1aml9cuM=";
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
    depsHash = "sha256-cwTHJ5Cd17ur8AhEQb8FTS0mcgqg83VGjvCQP00JY6s=";
    description = "Manage cargo cache ($CARGO_HOME or ~/.cargo/), show sizes and remove directories selectively";
    homepage = "https://github.com/matthiaskrgr/cargo-cache";
    id = "cargo-cache";
    keywords = ["cache" "cargo" "cargo-home" "cli" "manage"];
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
    crateSha256 = "sha256-IQZIy+OAzUurfMjvmlQ4NxXY1u6Dt2x+xa0NGeCiqeg=";
    depsHash = "sha256-hMWNd0J2AnXlt26/fgOY35q1Sp5xzS263vQRgnep7OM=";
    description = "A set of crate related cargo commands. You can for instance get the information about a crate, as text or json, including the owners of a crate and its versions.";
    homepage = "https://github.com/chevdor/cargo-crate";
    id = "cargo-crate";
    keywords = ["cargo" "cargo-subcommand" "cli" "crate"];
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
    version = "0.2.5";
  };
  cargo-deps = {
    crateSha256 = "sha256-qnSHG4AhBrleYKZ4SJ4AwHdJyiidj8NTeSSphBRo7gg=";
    depsHash = "sha256-cVi1mDlxUIO2R5aOCtcPWr24/kdq36lk1uEiKaBadmc=";
    description = "Cargo subcommand for building dependency graphs of Rust projects.";
    homepage = "https://github.com/mrcnski/cargo-deps";
    id = "cargo-deps";
    keywords = ["cargo" "dependencies" "graph" "graphviz" "visualization"];
    owners = [
      {
        avatar = "https://avatars.githubusercontent.com/u/6035856?v=4";
        email = null;
        id = 9430;
        kind = "user";
        login = "mrcnski";
        name = "Marcin S.";
        url = "https://github.com/mrcnski";
      }
    ];
    version = "1.5.1";
  };
  cargo-docs = {
    crateSha256 = "sha256-M+IkxIr8HG/Us1wWnPR6V+/JI4lMNCDh3pm47YyH9gU=";
    depsHash = "sha256-AtsUBGPhOzXNyZyvTZ8EE47OpEmaHJlrik1XwPuTGEY=";
    description = "A cargo plugin for serving rust and crate doc locally.";
    homepage = null;
    id = "cargo-docs";
    keywords = [];
    owners = [
      {
        avatar = "https://avatars.githubusercontent.com/u/54848194?v=4";
        email = null;
        id = 76113;
        kind = "user";
        login = "btwiuse";
        name = "Broken Pipe";
        url = "https://github.com/btwiuse";
      }
    ];
    version = "0.1.34";
  };
  cargo-expand = {
    crateSha256 = "sha256-36uvULhpIDlasX+4n0kr2NiFGQ+Uo/Vmfp8H+ChgUWQ=";
    depsHash = "sha256-69VoxVMmTzqbaULj/s9+DhITGZpwm70Wkn7QvL0AJ1E=";
    description = "Wrapper around rustc -Zunpretty=expanded. Shows the result of macro expansion and #[derive] expansion.";
    homepage = null;
    id = "cargo-expand";
    keywords = ["cargo" "macros" "subcommand"];
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
    version = "1.0.121";
  };
  cargo-lock = {
    crateSha256 = "sha256-l8B98ycfC17vUY29BbFoucGeAn8mapchCvjdMCNhKqc=";
    depsHash = "sha256-l76udCsgloW5tZ8TgNMOT47un2Epun0B3UjaHCWdZjE=";
    description = "Self-contained Cargo.lock parser with optional dependency graph analysis";
    documentation = null;
    homepage = "https://rustsec.org";
    id = "cargo-lock";
    keywords = ["cargo" "dependency" "lock" "lockfile"];
    owners = [
      {
        avatar = "https://avatars.githubusercontent.com/u/772?v=4";
        email = null;
        id = 163;
        kind = "user";
        login = "alex";
        name = "Alex Gaynor";
        url = "https://github.com/alex";
      }
      {
        avatar = "https://avatars.githubusercontent.com/u/797?v=4";
        email = null;
        id = 267;
        kind = "user";
        login = "tarcieri";
        name = "Tony Arcieri";
        url = "https://github.com/tarcieri";
      }
      {
        avatar = "https://avatars.githubusercontent.com/u/291257?v=4";
        email = null;
        id = 96567;
        kind = "user";
        login = "Shnatsel";
        name = "Sergey \"Shnatsel\" Davidoff";
        url = "https://github.com/Shnatsel";
      }
      {
        avatar = "https://avatars.githubusercontent.com/u/25397242?v=4";
        email = null;
        id = 12033;
        kind = "team";
        login = "github:rustsec:working-group";
        name = "Working Group";
        url = "https://github.com/rustsec";
      }
    ];
    version = "11.0.1";
  };
  cargo-public-api = {
    crateSha256 = "sha256-Lg8X0t5u4Mq/eWc0yfuLyn4HlE+j6qSsLE+MFBjBpbk=";
    depsHash = "sha256-OjuCABObMRkFrTbtV4wpSHzV9Yqmwr/VotmsUW9qUDk=";
    description = "List and diff the public API of Rust library crates between releases and commits. Detect breaking API changes and semver violations via CI or a CLI.";
    homepage = "https://github.com/cargo-public-api/cargo-public-api";
    id = "cargo-public-api";
    keywords = ["cargo-subcommand" "diff" "rustdoc-json" "semver"];
    owners = [
      {
        avatar = "https://avatars.githubusercontent.com/u/1502855?v=4";
        email = null;
        id = 5417;
        kind = "user";
        login = "Emilgardis";
        name = null;
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
    ];
    version = "0.50.2";
  };
  cargo-semver-checks = {
    crateSha256 = "sha256-jPgR4K4fH3onCtSaKr4UhoGk4WdonwDppI9GHgp4lSU=";
    depsHash = "sha256-lP4yXCuJ89NqUBZR6zgGi5B570y+5IaabWyzd9qqa3o=";
    description = "Scan your Rust crate for semver violations.";
    homepage = null;
    id = "cargo-semver-checks";
    keywords = ["cargo" "check" "crate" "linter" "semver"];
    owners = [
      {
        avatar = "https://avatars.githubusercontent.com/u/2348618?v=4";
        email = null;
        id = 167649;
        kind = "user";
        login = "obi1kenobi";
        name = "Predrag Gruevski";
        url = "https://github.com/obi1kenobi";
      }
    ];
    version = "0.46.0";
  };
  cargo-sort = {
    crateSha256 = "sha256-U/LakNUSPqj6FmYimi5ZNVJCRiS7zM4Vzvu4Gb3w38Q=";
    depsHash = "sha256-FoFzBf24mNDTRBfFyTEr9Q7sJjUhs0X/XWRGEoierQ4=";
    description = "Check if tables and items in a .toml file are lexically sorted";
    homepage = null;
    id = "cargo-sort";
    keywords = ["cargo" "check" "dependencies" "sort" "subcommand"];
    owners = [
      {
        avatar = "https://avatars.githubusercontent.com/u/951129?v=4";
        email = null;
        id = 6913;
        kind = "user";
        login = "jplatte";
        name = "Jonas Platte";
        url = "https://github.com/jplatte";
      }
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
    version = "2.0.2";
  };
  cargo-watch = {
    crateSha256 = "sha256-RKUf3sL3Q0iKl1vHPWNL1jG5OwKk+s28PK9RADEBqBc=";
    depsHash = "sha256-4AVZ747d6lOjxHN+co0A7APVB5Xj6g5p/Al5fLbgPnc=";
    description = "Watches over your Cargo project’s source";
    homepage = "https://watchexec.github.io/#cargo-watch";
    id = "cargo-watch";
    keywords = ["cargo" "compile" "notify" "watch"];
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
    version = "8.5.3";
  };
  octorus = {
    crateSha256 = "sha256-3W28wpZU+Nk3X0tHEO/qXTIMsEl49LykiN3T7RkvlKY=";
    depsHash = "sha256-P+YgruHe6+4ZaIQekyY+etAREHVPwHkrFd+DiCR+BT8=";
    description = "A TUI tool for GitHub PR review, designed for Helix editor users";
    homepage = null;
    id = "octorus";
    keywords = [];
    owners = [
      {
        avatar = "https://avatars.githubusercontent.com/u/30229874?v=4";
        email = null;
        id = 349066;
        kind = "user";
        login = "ushironoko";
        name = "ushironoko";
        url = "https://github.com/ushironoko";
      }
    ];
    version = "0.3.5";
  };
  toml-merge = {
    crateSha256 = "sha256-ZRfTxA5xjA/V6VtecwdyyGkMC6o+kd2ipRCwJ19Zvfg=";
    depsHash = "sha256-xZmPC+rqQVikIhbRZ0U2gQx9MvBfdSbALIUBJObtpiE=";
    description = "Simple CLI utility which merges TOML files.";
    homepage = null;
    id = "toml-merge";
    keywords = [];
    owners = [
      {
        avatar = "https://avatars.githubusercontent.com/u/645226?v=4";
        email = null;
        id = 82703;
        kind = "user";
        login = "mrnerdhair";
        name = "Reid Rankin";
        url = "https://github.com/mrnerdhair";
      }
    ];
    version = "0.2.0";
  };
  zellij = {
    crateSha256 = "sha256-7SjlPYa/CkQSNu0SyIjYycJuKaJ6RcGInSPVe3+xNMw=";
    depsHash = "sha256-xfNX5ccDWqnAn5n4/QyLHtvce1ZfXZg9iNNaR/5tjAs=";
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
        login = "h3nill";
        name = "Henil";
        url = "https://github.com/h3nill";
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
    version = "0.43.1";
  };
}
