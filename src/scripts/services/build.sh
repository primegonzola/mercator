#!/bin/bash
# build and compile, linl core library first
pushd mercator
npm --prefer-offline install
npm run build
npm link
popd
# modules to handle
MODULES="monitor"
# go over each function app
for module in $MODULES; do
	pushd ${module}
	npm --prefer-offline install
	npm link mercator
	npm run build
	# rm -rf node_modules
	# rm package-lock.json
	popd
done
