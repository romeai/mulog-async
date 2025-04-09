{
  description = "Fork of μ/log with built-in core.async support.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
    nix-filter.url = "github:numtide/nix-filter";
    clojure-nix-locker.url = "github:bevuta/clojure-nix-locker";
  };

  nixConfig = {
    extra-trusted-public-keys = [
      "romeai.cachix.org-1:XJ4CvxkU/6C6DwPGto8LRRCoBKNzfBsOp1TR//FHupU="
    ];
    extra-substituters = [
      "https://romeai.cachix.org"
    ];
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      clojure-nix-locker,
      nix-filter,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        version = pkgs.lib.removeSuffix "\n" (builtins.readFile "${self}/ver/mulog.version");
        filterSrc = nix-filter.lib;

        # Custom locker function to pin lein deps
        build-command = ''
          ${pkgs.babashka}/bin/bb build:core :skip-tests && \
          ${pkgs.babashka}/bin/bb -build:json :skip-tests && \
          ${pkgs.babashka}/bin/bb build:publishers :skip-tests && \
          ${pkgs.babashka}/bin/bb build:samplers :skip-tests
        '';
        lein-locker = clojure-nix-locker.lib.customLocker {
          inherit pkgs;
          lockfile = "./deps.lock.json";
          command = build-command;
          src = ./.;
        };

        # A derivation that runs your build command and stages the built jars.
        commonBuild = pkgs.stdenv.mkDerivation {
          pname = "mulog-build";
          inherit version;
          src = filterSrc {
            root = ./.;
            exclude = [
              "README.md"
              "flake.nix"
              "flake.lock"
              "doc"
              "examples"
              ".github"
            ];
          };
          nativeBuildInputs = [
            pkgs.babashka
            pkgs.leiningen
          ];
          buildInputs = [ pkgs.jdk ];
          # Run the build command to build all jars.
          buildPhase = ''
            # Hook our cached lein deps into the build, but keep the m2 repo
            # writeable, since the builder needs to install the mulog-core jar
            # to be accessible by the other subprojects.

            echo "Hooking in home from ${lein-locker.homeDirectory}"
            tmp=$(mktemp -d)
            cp -rLT "${lein-locker.homeDirectory}/" "$tmp/"
            chmod -R u+w "$tmp"

            export HOME="$tmp"
            export JAVA_TOOL_OPTIONS="-Duser.home=$tmp"

            ${build-command}
          '';
          # Stage the entire "target" folder for easy pickup.
          installPhase = ''
            mkdir -p $out
            for result in */target; do
              subproj=$(dirname $result)
              mkdir -p "$out/$subproj"
              cp -r "$result" "$out/$subproj"
            done
          '';
          meta = with pkgs.lib; {
            description = "Builds all μ/log jars using bb";
            license = licenses.asl20;
          };
        };

        # Helper to package one jar file from the common build output.
        #
        # Assumes that the jar is located at
        #   $commonBuild/out/target/<subproject>/<jar-file>
        # and that you want to install it under $out/share/java.
        mkJarPackage =
          { name, jarRelPath }:
          pkgs.stdenv.mkDerivation {
            pname = name;
            inherit version;
            # Use the common build as the source; note that this creates a dependency:
            src = commonBuild;
            # Nothing to compile here.
            buildPhase = "true";
            installPhase = ''
              mkdir -p $out/share/java
              cp "${commonBuild}/${jarRelPath}" $out/share/java/
            '';
            meta = with pkgs.lib; {
              description = "${name} jar built from μ/log sources";
              license = licenses.asl20;
            };
          };

        # Create one derivation for each jar file.
        mulog-adv-console = mkJarPackage {
          name = "mulog-adv-console";
          jarRelPath = "mulog-adv-console/target/mulog-adv-console-${version}.jar";
        };

        mulog-adv-file = mkJarPackage {
          name = "mulog-adv-file";
          jarRelPath = "mulog-adv-file/target/mulog-adv-file-${version}.jar";
        };

        mulog-cloudwatch = mkJarPackage {
          name = "mulog-cloudwatch";
          jarRelPath = "mulog-cloudwatch/target/mulog-cloudwatch-${version}.jar";
        };

        mulog-core = mkJarPackage {
          name = "mulog-core";
          jarRelPath = "mulog-core/target/mulog-${version}.jar";
        };

        mulog-elasticsearch = mkJarPackage {
          name = "mulog-elasticsearch";
          jarRelPath = "mulog-elasticsearch/target/mulog-elasticsearch-${version}.jar";
        };

        mulog-filesystem-metrics = mkJarPackage {
          name = "mulog-filesystem-metrics";
          jarRelPath = "mulog-filesystem-metrics/target/mulog-filesystem-metrics-${version}.jar";
        };

        mulog-json = mkJarPackage {
          name = "mulog-json";
          jarRelPath = "mulog-json/target/mulog-json-${version}.jar";
        };

        mulog-jvm-metrics = mkJarPackage {
          name = "mulog-jvm-metrics";
          jarRelPath = "mulog-jvm-metrics/target/mulog-jvm-metrics-${version}.jar";
        };

        mulog-kafka = mkJarPackage {
          name = "mulog-kafka";
          jarRelPath = "mulog-kafka/target/mulog-kafka-${version}.jar";
        };

        mulog-kinesis = mkJarPackage {
          name = "mulog-kinesis";
          jarRelPath = "mulog-kinesis/target/mulog-kinesis-${version}.jar";
        };

        mulog-mbean-sampler = mkJarPackage {
          name = "mulog-mbean-sampler";
          jarRelPath = "mulog-mbean-sampler/target/mulog-mbean-sampler-${version}.jar";
        };

        mulog-opentelemetry = mkJarPackage {
          name = "mulog-opentelemetry";
          jarRelPath = "mulog-opentelemetry/target/mulog-opentelemetry-${version}.jar";
        };

        mulog-prometheus = mkJarPackage {
          name = "mulog-prometheus";
          jarRelPath = "mulog-prometheus/target/mulog-prometheus-${version}.jar";
        };

        mulog-slack = mkJarPackage {
          name = "mulog-slack";
          jarRelPath = "mulog-slack/target/mulog-slack-${version}.jar";
        };

        mulog-zipkin = mkJarPackage {
          name = "mulog-zipkin";
          jarRelPath = "mulog-zipkin/target/mulog-zipkin-${version}.jar";
        };

        # An "all" package that aggregates all the jars.
        #
        # One common approach is to add all jar packages as buildInputs and then copy every jar into
        # a single folder (e.g. $out/share/java).
        all = pkgs.stdenv.mkDerivation {
          pname = "mulog-all";
          inherit version;
          src = commonBuild;
          buildInputs = [
            mulog-adv-console
            mulog-adv-file
            mulog-cloudwatch
            mulog-core
            mulog-elasticsearch
            mulog-filesystem-metrics
            mulog-json
            mulog-jvm-metrics
            mulog-kafka
            mulog-kinesis
            mulog-mbean-sampler
            mulog-opentelemetry
            mulog-prometheus
            mulog-slack
            mulog-zipkin
          ];
          # no-op build phase
          buildPhase = "true";
          installPhase = ''
            mkdir -p $out/share/java
            cp ${mulog-adv-console}/share/java/* $out/share/java/
            cp ${mulog-adv-file}/share/java/* $out/share/java/
            cp ${mulog-cloudwatch}/share/java/* $out/share/java/
            cp ${mulog-core}/share/java/* $out/share/java/
            cp ${mulog-elasticsearch}/share/java/* $out/share/java/
            cp ${mulog-filesystem-metrics}/share/java/* $out/share/java/
            cp ${mulog-json}/share/java/* $out/share/java/
            cp ${mulog-jvm-metrics}/share/java/* $out/share/java/
            cp ${mulog-kafka}/share/java/* $out/share/java/
            cp ${mulog-kinesis}/share/java/* $out/share/java/
            cp ${mulog-mbean-sampler}/share/java/* $out/share/java/
            cp ${mulog-opentelemetry}/share/java/* $out/share/java/
            cp ${mulog-prometheus}/share/java/* $out/share/java/
            cp ${mulog-slack}/share/java/* $out/share/java/
            cp ${mulog-zipkin}/share/java/* $out/share/java/
          '';

          meta = with pkgs.lib; {
            description = "Aggregates all μ/log jar files into one package";
            license = licenses.asl20;
          };
        };

      in
      {
        apps.lock-deps = flake-utils.lib.mkApp {
          drv = lein-locker.locker;
        };

        packages = {
          mulog-adv-console = mulog-adv-console;
          mulog-adv-file = mulog-adv-file;
          mulog-cloudwatch = mulog-cloudwatch;
          mulog-core = mulog-core;
          mulog-elasticsearch = mulog-elasticsearch;
          mulog-filesystem-metrics = mulog-filesystem-metrics;
          mulog-json = mulog-json;
          mulog-jvm-metrics = mulog-jvm-metrics;
          mulog-kafka = mulog-kafka;
          mulog-kinesis = mulog-kinesis;
          mulog-mbean-sampler = mulog-mbean-sampler;
          mulog-opentelemetry = mulog-opentelemetry;
          mulog-prometheus = mulog-prometheus;
          mulog-slack = mulog-slack;
          mulog-zipkin = mulog-zipkin;
          mulog-all = all;
        };
      }
    );
}
