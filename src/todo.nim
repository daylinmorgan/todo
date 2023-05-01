import std/[os, tables]
import todo/cli, todo/config

when isMainModule:
  import cligen

  proc mergeParams(cmdNames: seq[string]; cmdLine = commandLineParams()): seq[string] =
    if cmdNames == @["multi"] and cmdLine.len == 0:
      return cfg.`default-cmd`.parseCmdLine
    else: return cmdLine

  const
    customMulti = "${doc}Usage:\n  $command {SUBCMD} [sub-command options & parameters]\n\nsubcommands:\n$subcmds"
    vsn = staticExec "git describe --tags --always HEAD"


  if clCfg.useMulti == "": clCfg.useMulti = customMulti
  if clCfg.helpAttr.len == 0:
    clCfg.helpAttr = {"cmd": "\e[1;36m", "clDescrip": "", "clDflVal": "\e[33m",
        "clOptKeys": "\e[32m", "clValType": "\e[31m", "args": "\e[3m"}.toTable
    clCfg.helpAttrOff = {"cmd": "\e[m", "clDescrip": "\e[m", "clDflVal": "\e[m",
        "clOptKeys": "\e[m", "clValType": "\e[m", "args": "\e[m"}.toTable

  var vsnCfg = clCfg
  vsnCfg.version = vsn

  dispatchMulti(
      ["multi", cf = vsnCfg],
      [show, short = {"hide": 'H', "working-directory": 'W'},
      help = {
              "global": "use global todo list",
              "hide": "hide completed tasks",
              "status": "only show status line",
              "todo": "only show tasks",
              "working-directory": "set current working directory",
              "quiet": "show nothing if no todo's found"
        }
      ],
      [clearItems, cmdName = "clear",
        help = {
              "global": "use global todo list",
              "yes": "answer yes to all prompts",
              "working-directory": "set current working directory"
        }, ],
      [edit,
      help = {
              "global": "use global todo list",
              "working-directory": "set current working directory"
        }
          ],
      [list,
      help = {
          "absolute": "show absolute path to todo's"}
        ],
      [database, cmdName = "db",
      help = {
          "add": "path to todo's to track",
          "del": "path to todo's to forget"}
        ],
      [grep, help = {
          "symbol": "comment indicator",
          "args": "additional args passed to grep",
          "working-directory": "set current working directory"
        }],
      [commit,
        help = {
          "yes": "answer yes to all prompts"
        }
      ]
    )


