# Package

version       = "2023.1001"
author        = "Daylin Morgan"
description   = "simple markdown-based todo app"
license       = "MIT"
srcDir        = "src"
bin           = @["todo"]
binDir        = "bin"


# Dependencies

requires "nim >= 1.6.10",
         "cligen",
         "regex",
         "yaml"


import strformat
const targets = [
    "x86_64-linux-gnu",
    "aarch64-linux-gnu",
    "x86_64-linux-musl",
    "x86_64-macos-none",
    "aarch64-macos-none",
    "x86_64-windows-gnu"
  ]

task release, "build release assets":
  mkdir "dist"
  for target in targets:
    let
      app = projectName()
      ext = if target == "x86_64-windows-gnu": ".exe" else: ""
      outdir = &"dist/{app}-v{version}-{target}/"
    exec &"ccnz cc --target {target} --nimble -- --out:{outdir}{app}{ext} -d:release src/{app}"

task bundle, "package build assets":
  cd "dist"
  for target in targets:
    let
      archiveName = &"{projectName()}-v{version}-{target}"
      cmd =
        if target == "x86_64-windows-gnu":
          &"7z a {archiveName}.zip {archiveName}"
        else:
          &"tar czf {archiveName}.tar.gz {archiveName}"
    cpFile("../README.md", &"{archiveName}/README.md")
    exec cmd



