import std/[os]
import yaml, streams

type
  TodoConfig* = object
    patterns*{.defaultVal: @["todo.md", ".todo.md"].}: seq[string]
    `case-sensitive`* {.defaultVal: false.}: bool
    `default-cmd`* {.defaultVal: "show".}: string

const defaultCfg = """
patterns:
  - todo.md
  - .todo.md
default-cmd: show
case-sensitive: false
"""
proc loadConfig*(): TodoConfig =
  var cfg: TodoConfig

  # TODO: yml or yaml...
  let configFile = getConfigDir() / "todo" / "config.yml"
  if fileExists(configFile):
    let s = newFileStream(configFile)
    load(s, cfg)
    s.close()
  else:
    load(defaultCfg, cfg)

  return cfg

let cfg* = loadConfig()
