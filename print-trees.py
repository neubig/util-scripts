#!/usr/bin/env python

'''A program to display parse trees (in Penn treebank format)
with the NLTK.
'''

import sys

try:
  from nltk.tree import Tree
except ImportError:
  print('Error: cannot import the NLTK!')
  print('You need to install the NLTK. Please visit http://nltk.org/install.html for details.')
  print("On Ubuntu, the installation can be done via 'sudo apt-get install python-nltk'")
  sys.exit()

def main():
  for line in sys.stdin:
    t = Tree.fromstring(line)
    t.draw()

if __name__ == '__main__':
  main()
