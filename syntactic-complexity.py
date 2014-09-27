#!/usr/bin/env python

'''
A program to calculate syntactic complexity of parse trees. (Relies on NLTK)
This is an implementation of some of the methods in:

Syntactic complexity measures for detecting Mild Cognitive Impairment
Brian Roark, Margaret Mitchell and Kristy Hollingshead
Proc BioNLP 2007.
'''

import sys

try:
  from nltk.tree import Tree
  from nltk.draw.tree import TreeWidget
  from nltk.draw.util import (CanvasFrame, CanvasWidget, BoxWidget,
                              TextWidget, ParenWidget, OvalWidget)
except ImportError:
  print 'Error: cannot import the NLTK!'
  print 'You need to install the NLTK. Please visit http://nltk.org/install.html for details.'
  print "On Ubuntu, the installation can be done via 'sudo apt-get install python-nltk'"
  sys.exit()

def calc_words(t):
    if type(t) == str:
        return 1
    else:
        val = 0
        for child in t:
            val += calc_words(child)
        return val

def calc_nodes(t):
    if type(t) == str:
        return 0
    else:
        val = 0
        for child in t:
            val += calc_nodes(child)+1
        return val

def calc_yngve(t, par):
    if type(t) == str:
        return par
    else:
        val = 0
        for i, child in enumerate(reversed(t)):
            val += calc_yngve(child, par+i)
        return val

def is_sent(val):
    return len(val) > 0 and val[0] == "S"

def calc_frazier(t, par, par_lab):
    # print t
    # print par
    if type(t) == str:
        # print par-1
        return par-1
    else:
        val = 0
        for i, child in enumerate(t):
            # For all but the leftmost child, zero
            score = 0
            if i == 0:
                my_lab = t.node
                # If it's a sentence, and not duplicated, add 1.5
                if is_sent(my_lab):
                    score = (0 if is_sent(par_lab) else par+1.5)
                # Otherwise, unless it's a root node, add one
                elif my_lab != "" and my_lab != "ROOT" and my_lab != "TOP":
                    score = par + 1
            val += calc_frazier(child, score, my_lab)
        return val

def main():
    sents = 0
    words_tot = 0
    yngve_tot = 0
    frazier_tot = 0
    nodes_tot = 0
    for line in sys.stdin:
        if line.strip() == "":
            continue
        t = Tree.parse(line)
        words = calc_words(t)
        words_tot += words
        sents += 1
        yngve = calc_yngve(t, 0)
        yngve_avg = float(yngve)/words
        yngve_tot += yngve_avg
        nodes = calc_nodes(t)
        nodes_avg = float(nodes)/words
        nodes_tot += nodes_avg
        frazier = calc_frazier(t, 0, "")
        frazier_avg = float(frazier)/words
        frazier_tot += frazier_avg
        # print "Sentence=%d\twords=%d\tyngve=%f\tfrazier=%f\tnodes=%f" % (sents, words, yngve_avg, frazier_avg, nodes_avg)
    yngve_avg = float(yngve_tot)/sents
    frazier_avg = float(frazier_tot)/sents
    nodes_avg = float(nodes_tot)/sents
    words_avg = float(words_tot)/sents
    print "Total\tsents=%d\twords=%f\tyngve=%f\tfrazier=%f\tnodes=%f" % (sents, words_avg, yngve_avg, frazier_avg, nodes_avg)

if __name__ == '__main__':
  main()
