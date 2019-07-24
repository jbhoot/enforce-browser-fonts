## Tested on OS

Fedora release 30 (Thirty). Install commands in this readme pertain to Fedora

## Tool and package pre-requisites to build the addon:

These instructions/commands are separated from `build-script.sh` because they install the environment, and so are one-off, and also because these commands require `sudo`.

1. Install `node.js` (v6.0.0+, most recent version preferred).

    `sudo dnf install nodejs`

2. Install npm

    `sudo dnf install npm`

3. Install the OpenJDK Java Runtime Environment (Version 8). JVM is required by the compiler package `shadow-cljs`, which compiles clojurescript into javascript.

  `sudo dnf install java-1.8.0-openjdk-headless`

4. Now build script can be run.

  `sh build-script.sh`
