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
         "yaml >= 2.0.0",
         "https://github.com/daylinmorgan/bbansi#head"



