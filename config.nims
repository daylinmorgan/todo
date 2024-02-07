import std/[strformat, strutils]

# https://github.com/nim-lang/Nim/issues/23289
patchFile("stdlib", "parsecfg", "src/todo/private/parsecfg")

task build, "build":
  selfExec "c -d:release -o:bin/todo src/todo.nim"

task release, "build release assets":
  version = (gorgeEx "git describe --tags --always --match 'v*'").output
  exec &"forge release -v {version} -V"

task bundle, "package build assets":
  withDir "dist":
    for dir in listDirs("."):
      let cmd = if "windows" in dir:
        &"zip -qr {dir}.zip {dir}"
      else: 
        &"tar czf {dir}.tar.gz {dir}"
      cpFile("../README.md", &"{dir}/README.md")
      exec cmd
