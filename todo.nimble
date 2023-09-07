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

task release, "build release assets":
  version = (gorgeEx "git describe --tags --always --match 'v*'").output
  exec &"forge release -v {version} -V"

task bundle, "package build assets":
  withDir "dist":
    for dir in listDirs("."):
      let cmd = if "windows" in dir:
        &"7z a {dir}.zip {dir}"
      else: 
        &"tar czf {dir}.tar.gz {dir}"
      cpFile("../README.md", &"{dir}/README.md")
      exec cmd


