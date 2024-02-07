import std/[os, parsecfg, parseutils, strutils, sugar]

type
  TodoConfig = object
    patterns*:seq[string] = @["todo.md",".todo.md"]
    caseSensitive*:bool = true
    defaultCmd*: string = "show"

proc loadTodoCfg*(): TodoConfig = 
  result = TodoConfig()
  let cfgFile = getConfigDir() / "todo" / "todo.cfg"
  if not fileExists cfgFile: return

  let dict = loadConfig(cfgFile)
  let patterns = dict.getSectionValue("","patterns")
  if patterns.len > 0 and (',' in patterns or '\n' in patterns):
    let splitChar = 
      if "," in patterns: ',' 
      else: '\n'
    result.patterns = collect(for i in patterns.split(splitChar): i.strip())
  elif patterns.len > 0:
    result.patterns = @[patterns]
 
  let ignoreCaseSet = dict.getSectionValue("", "caseSensitive")
  if ignoreCaseSet.len > 0:
    result.caseSensitive = parseBool(ignoreCaseSet)
  
  result.defaultCmd = dict.getSectionValue("", "defaultCmd", result.defaultCmd)

let cfg* = loadTodoCfg()




