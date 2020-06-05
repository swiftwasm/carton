const path = require("path");
const outputPath = path.resolve(__dirname, "Public");

module.exports = {
  entry: "./entrypoint/dev.js",
  mode: "development",
  output: {
    filename: "dev.js",
    path: outputPath,
  },
};
