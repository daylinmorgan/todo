import std/[os, tables]
import cligen, hwylterm, hwylterm/cligen
import todo/[cli, config]

proc mergeParams(cmdNames: seq[string]; cmdLine = commandLineParams()): seq[string] =
    if cmdNames == @["multi"] and cmdLine.len == 0:
      return cfg.defaultCmd.parseCmdLine
    else: return cmdLine

type
  Help = Table[string,string]
  HelpPairs = openArray[(string,string)]
func `//`*(p: HelpPairs): Help =
  p.toTable()
func `//`*(x: var Help, y: Help) =
  for (k, v) in y.pairs: x[k] = v
func `//`*(x, y: Help): Help =
  result // x; result // y
func `//`*(x: Help, p: HelpPairs): Help =
  result // x; result // p.toTable()

when isMainModule:
  const todoVersion {.strdefine.} = staticExec "git describe --tags --always HEAD"
  var vsnCfg = clCfg
  vsnCfg.version = todoVersion
 
  let clUse = $bb("$command $args\n${doc}[bold]Options[/]:\n$options")
  hwylCli(clCfg)

  const
    absolute = //{"absolute": "show absolute path to todo's"}
    yes = //{"yes":"answer yes to all prompts"}
    working = //{"working-directory": "set current working directory"}
    global = //{"global": "use global todo list"}
    shared = working//global
    showHelp = shared//{
      "hide": "hide completed tasks",
      "status": "only show status line",
      "todo": "only show tasks",
      "quiet": "show nothing if no todo's found"
    }
    clearHelp = shared // yes
    dbHelp = //{
      "add": "path to todo's to track",
      "del": "path to todo's to forget"
    }
    grepHelp = working//{
      "symbol": "comment indicator",
      "args"  : "additional args passed to grep",
    }
  dispatchMulti(
      ["multi", cf = vsnCfg],
      [show,       help = showHelp , usage = clUse, short = {"hide": 'H', "working-directory": 'W'}],
      [clearItems, help = clearHelp, usage = clUse, cmdName = "clear"],
      [edit,       help = shared   , usage = clUse],
      [list,       help = absolute , usage = clUse],
      [database,   help = dbHelp   , usage = clUse, cmdName = "db"],
      [grep,       help = grepHelp , usage = clUse],
      [commit,     help = yes      , usage = clUse]
    )


