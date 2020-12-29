const path = require("path");
const outputPath = path.resolve(__dirname, "../static");

module.exports = {
  entry: "./entrypoint/test.js",
  mode: "development",
  output: {
    filename: "test.js",
    path: outputPath,
  },
};
