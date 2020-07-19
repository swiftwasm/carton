const path = require("path");
const outputPath = path.resolve(__dirname, "static");

module.exports = {
  entry: "./entrypoint/dev.js",
  mode: "development",
  output: {
    filename: "dev.js",
    path: outputPath,
  },
};
