######Q: What do VSCode Extentions use for SDK to build a new extention? 

A: Building a new extension for Visual Studio Code (VSCode) doesn't necessarily require an SDK like some other platforms do. VSCode is built on top of Electron which is a framework for creating desktop applications with web technologies like JavaScript, HTML, and CSS.

To create a VSCode extension, you need to have Node.js and npm installed on your machine. The yo code command (from the Yeoman scaffolding tool) is used to generate a new extension project. The generated project includes a package.json file which defines the extension's metadata, an extension.js (or extension.ts for TypeScript) file which is the main entry point of your extension, and various configuration and script files.

You can find more details about creating a new extension in the official VSCode Extension API: [https://code.visualstudio.com/api/get-started/your-first-extension](docs)

You can also take a look at the "Extension API" section of the documentation for a detailed description of all the APIs you can use in your extension: https://code.visualstudio.com/api/references/vscode-api

As for debugging and testing your extension, VSCode provides a debug environment. You can run and debug your extension using the .vscode/launch.json configuration file included in the generated project.

For more detailed information, you can also check out the "Extension Capabilities", "Extension Guides", and "Advanced Topics" sections of the official documentation.


