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

proc pickConfigFile(): string =
  let configDir = getConfigDir() / "todo"
  if not dirExists configDir:
    return "config.yml"

  if fileExists "config.yml":
    return "config.yml"
  elif fileExists "config.yaml":
    return "config.yaml"
  else:
    return "config.yml"

proc loadConfig*(): TodoConfig =

  let configFile = pickConfigFile()
  if fileExists(configFile):
    let s = newFileStream(configFile)
    load(s, result)
    s.close()
  else:
    load(defaultCfg, result)

let cfg* = loadConfig()
