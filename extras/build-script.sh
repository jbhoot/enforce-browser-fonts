# Check readme-for-build.md for pre-requisites

cd ./cljs-version

# Install locally from package-lock.json.
# Main package is: `shadow-cljs`. Rest are dependencies.
npm ci

# compile cljs source into js equivalent
# built as: cljs-version/build/bg-script.js
# reviewer would want to diff the above mentioned file
npx shadow-cljs release app

cd ..

# create or update test.xpi
mkdir -p releases
zip -r releases/test.xpi cljs-version/build/bg-script.js icons/ manifest.json
