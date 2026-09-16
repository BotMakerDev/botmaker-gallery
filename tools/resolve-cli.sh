#!/usr/bin/env bash
#
# resolve-cli.sh <output-file> — resolve botmaker-cli's MAIN artifact (the library) from JitPack and write its
# runtime classpath to <output-file>.
#
# EVERY RULE THIS GALLERY ENFORCES IS IN THAT ARTIFACT, not here: GalleryGate (validate.yml), ListingPolicy
# (automerge.yml) and CatalogBuilder (index.yml) are com.botmaker.cli.gallery classes. `botmaker bot publish`
# runs the same gate on the author's machine, so a refusal here is one they could already have seen.
#
# THE VERSION IS tools/botmaker-cli.version, one line, and it is pinned rather than floating: a verdict must
# not change under a pull request that is already open. Bump it in a pull request of its own.
#
# A pull request that edits this file or the version gets a check computed by its own copy — and that is
# fine, because automerge.yml hands any pull request touching a path outside bots/ to a maintainer.
set -euo pipefail

out="$1"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$root/tools/botmaker-cli.version")"
work="$(mktemp -d)"

cat > "$work/pom.xml" <<POM
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.botmaker.gallery</groupId>
    <artifactId>gate</artifactId>
    <version>0-SNAPSHOT</version>
    <packaging>pom</packaging>
    <repositories>
        <repository>
            <id>jitpack.io</id>
            <url>https://jitpack.io</url>
        </repository>
    </repositories>
    <dependencies>
        <dependency>
            <groupId>com.github.LiQiyeDev</groupId>
            <artifactId>botmaker-cli</artifactId>
            <version>$version</version>
        </dependency>
    </dependencies>
</project>
POM

# An ABSOLUTE outputFile: a relative one resolves against the pom's basedir. The plugin registry found that
# the hard way on its first pull request.
case "$out" in
    /*) ;;
    *) out="$PWD/$out" ;;
esac
mvn -B -q -f "$work/pom.xml" dependency:build-classpath -DincludeScope=runtime -Dmdep.outputFile="$out"
# The gate must not be reported as missing when what is missing is its classpath.
test -s "$out"
echo "botmaker-cli $version resolved." >&2
