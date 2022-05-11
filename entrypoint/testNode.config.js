const path = require("path");
const outputPath = path.resolve(__dirname, "../static");

module.exports = {
  entry: "./entrypoint/testNode.js",
  mode: "development",
  target: "node",
  output: {
    filename: "testNode.js",
    path: outputPath,
    libraryTarget: "commonjs"
  },
  node: {
    __dirname: false,
    __filename: false,
  },
  resolve: {
    mainFields: ["main", "module"],
  },
};
