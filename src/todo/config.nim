import std/[os, parsecfg,
            sequtils, sets,
    strutils, sugar, tables
]

import bbansi

type
  TodoConfig = object
    patterns*: seq[string] = @["todo.md", ".todo.md"]
    caseSensitive*: bool = true
    defaultCmd*: string = "show"

template attemptParse(param: string, msg: string, body: untyped) =
  try:
    body
  except ValueError:
    echo "[b red]ConfigError[/] ".bb, msg
    quit 1

const validKeys = ["patterns", "defaultCmd", "caseSensitive"]

proc configCheck(c: Config) =
  for sect in c.sections:
    if sect != "":
      bbEcho "[b yellow]Warning[/] ignoring unknown section: ", sect
  if "" in c:
    let unknownKeys = c[""].keys().toSeq().toHashSet() - validKeys.toHashSet()
    for k in unknownKeys:
      bbEcho "[b yellow]Warning[/] ignoring unknown key: ", k


proc loadTodoCfg*(): TodoConfig =
  result = TodoConfig()
  let cfgFile = getConfigDir() / "todo" / "todo.cfg"
  if not fileExists cfgFile: return

  let dict = loadConfig(cfgFile)
  configCheck dict
  let patterns = dict.getSectionValue("", "patterns")
  if patterns.len > 0 and (',' in patterns or '\n' in patterns):
    let splitChar =
      if "," in patterns: ','
      else: '\n'
    result.patterns = collect(for i in patterns.split(splitChar): i.strip())
  elif patterns.len > 0:
    result.patterns = @[patterns]
  let ignoreCaseSet = dict.getSectionValue("", "caseSensitive")
  if ignoreCaseSet.len > 0:
    attemptParse "caseSensitive", "failed to parse value for `caseSensitive` as bool":
      result.caseSensitive = parseBool(ignoreCaseSet)
  result.defaultCmd = dict.getSectionValue("", "defaultCmd", result.defaultCmd)

let cfg* = loadTodoCfg()




