# carton 📦

`carton` is a watcher, bundler, and test runner for your SwiftWasm apps. The main goal of `carton` is to provide the most smooth zero-config experience when developing for WebAssembly.

When using `carton` you don't have to install Node.js or to write your own webpack configs. `carton` itself uses webpack as a dev dependency to precompile and minify the required WASI polyfill and the reload-on-rebuild code, but you won't need webpack or Node.js when using carton as an end user. The polyfill is distributed to you precompiled.

It is currently work in progress, so watch the repository for imminent updates!
