import fs from "fs";
import path from "path";
import * as sass from "sass";
import { buildAPI, buildWebview } from "./platform/node/src/build";
import { buildSync } from "esbuild";
import { mingleAPI, mingleWebview } from "./editor/api/projects/mingle";

if (fs.existsSync("dist"))
    fs.rmSync("dist", { recursive: true })

const scanRecursive = (item: fs.Dirent) => {
    const itemPath = path.join(item.path, item.name)
    if (item.isFile()) return itemPath;
    return scan(itemPath)
}

const scan = (directory: string): string[] => {
    return fs.readdirSync(directory, { withFileTypes: true }).map(scanRecursive).flat()
}

const scssFiles = scan("editor/webview").filter(filePath => filePath.endsWith(".scss"));

const compileScss = async (scssFile: string) => {
    const { css } = await sass.compileAsync(scssFile);
    if (css.length)
        fs.writeFileSync(scssFile.slice(0, -4) + "css", css);
}
const compilePromises = scssFiles.map(compileScss);
await Promise.all(compilePromises);


buildSync({
    entryPoints: ["src/api.ts"],
    bundle: true,
    format: "esm",
    outfile: "src/js/api.js"
})

buildSync({
    entryPoints: ["src/webview.ts"],
    bundle: true,
    format: "esm",
    outfile: "src/js/webview.js"
})

global.fs = {
    readfileUTF8: (file: string) => fs.readFileSync(file, { encoding: "utf-8" }),
    putfileUTF8: (file: string, contents: string) => fs.writeFileSync(file, contents)
}
global.webviewBase = "src/js/webview.js";
global.apiBase = "src/js/api.js";
global.resolvePath = (entrypoint: string) => entrypoint

const entrypointWebview = mingleWebview("../editor/webview/index.ts");
buildWebview(entrypointWebview, "dist/webview");
fs.rmSync(entrypointWebview);

// cleanup
scssFiles.forEach(scssFile => {
    const cssFile = scssFile.slice(0, -4) + "css";
    if (fs.existsSync(cssFile))
        fs.rmSync(cssFile);
});

fs.cpSync("editor/webview/index.html", "dist/webview/index.html");
fs.cpSync("editor/webview/assets", "dist/webview/assets", { recursive: true });

const entrypointAPI = mingleAPI("../editor/api/index.ts");
const api = buildAPI(entrypointAPI);
fs.rmSync(entrypointAPI);
fs.mkdirSync("dist/api", { recursive: true });
fs.writeFileSync("dist/api/index.js", api as string);