This file lists the steps to produce the submitted version of the add-on for the add-on reviewers. The steps have been tested on macOS Catalina.

Note that the `js` files produced thus may not exactly match with those of the submitted version, because the Google Closure compiler, used under the hood by the ClojureScript compiler, uses random symbol names during every compilation.

1. Install clojure.

```shell script
brew install clojure/tools/clojure  # for macOS

# Instructions for other OS at: https://clojure.org/guides/getting_started
```

2. Go to the source's root dir, in which `deps.edn` is located

3. Compile the `js` files. The `js` files compiled in this step will be placed in the `build` dir.

```shell script
# to compile build/js/core.js
clj --main cljs.main --compile-opts cljs-compile-options/prod/core.edn --compile ebf.core

# to compile build/js/preferences.js
clj --main cljs.main --compile-opts cljs-compile-options/prod/preferences.edn --compile ebf.preferences
```

4. Now the `build` dir contains the compiled source code for the add-on. Run it or build it using the `web-ext` tool provided by Mozilla.

```shell script
cd build

# run
web-ext run

# or build
web-ext build
```