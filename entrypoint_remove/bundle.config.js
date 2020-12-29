const path = require("path");
const outputPath = path.resolve(__dirname, "../static");

module.exports = {
  entry: "./entrypoint/bundle.js",
  mode: "production",
  output: {
    filename: "bundle.js",
    path: outputPath,
  },
};
