let path = require('path');
let webpack = require('webpack');

module.exports = {
  entry: './index.ts',
  target: 'node',
  mode: 'production',
  output: {
    path: path.join(__dirname),
    filename: './dist/index.js',
    library: "index",
    libraryTarget: "commonjs2"
  },
  resolve: {
    // Add `.ts` and `.tsx` as a resolvable extension.
    extensions: ['.ts', '.tsx', '.js']
  },
  node: {
    __filename: false,
    __dirname: false,
  },
  module: {
    rules: [
      // all files with a `.ts` or `.tsx` extension will be handled by `ts-loader`
      { test: /\.tsx?$/, loader: 'ts-loader' }
    ]
  },
  "optimization": {
    minimize: false
  }
}
