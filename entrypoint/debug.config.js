const path = require("path");
const outputPath = path.resolve(__dirname, "../static");

module.exports = {
  entry: "./entrypoint/debug.js",
  mode: "development",
  output: {
    filename: "debug.js",
    path: outputPath,
  },
};
