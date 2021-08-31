#!/usr/bin/env python3

import cloc
import os, sys
from pathlib import Path
import sys

def count_lines(paths):
    c = cloc.Cloc()
    for path in paths:
        c.count_path(path)
    c.report(verbose=False)

if __name__ == '__main__':
    count_lines(sys.argv[1:])
