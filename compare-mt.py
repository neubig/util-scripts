import sys
import argparse
import operator
from collections import defaultdict

parser = argparse.ArgumentParser(
    description='Program to compare MT results',
)
parser.add_argument('ref', type=str, help='A path to a correct reference file')
parser.add_argument('out', type=str, help='A path to a system output')
parser.add_argument('otherout', nargs='?', type=str, default=None, help='A path to another system output. Add only if you want to compare outputs from two systems.')
parser.add_argument('--alpha', type=float, default=1.0, help='A smoothing coefficient to control how much the model focuses on low- and high-frequency events. 1.0 should be fine most of the time.')
parser.add_argument('--ngram', type=int, default=4, help='Maximum length of n-grams.')
parser.add_argument('--printsize', type=int, default=50, help='How many n-grams to print.')
args = parser.parse_args()

with open(args.ref, "r") as f:
  ref = [line.strip().split() for line in f]
with open(args.out, "r") as f:
  out = [line.strip().split() for line in f]
if args.otherout != None:
  with args.otherout as f:
    out2 = [line.strip().split() for line in f]

def calc_ngrams(sent):
  ret = defaultdict(lambda: 0)
  for n in range(args.ngram):
    for i in range(len(sent)-n):
      ret[tuple(sent[i:i+n+1])] += 1
  return ret

def match_ngrams(left, right):
  ret = {}
  for k, v in left.items():
    if k in right.items():
      ret[k] = min(v, right[k])
  return ret

# Analyze the reference/output
if args.otherout == None:
  refall = defaultdict(lambda: 0)
  outall = defaultdict(lambda: 0)
  for refsent, outsent in zip(ref, out):
    for k, v in calc_ngrams(refsent).items():
      refall[k] += v
    for k, v in calc_ngrams(outsent).items():
      outall[k] += v
  scores = {}
  for k, v in refall.items():
    scores[k] = (v + args.alpha) / (v + outall[k] + 2*args.alpha)
  for k, v in outall.items():
    scores[k] = (refall[k] + args.alpha) / (refall[k] + v + 2*args.alpha)
  scorelist = sorted(scores.items(), key=operator.itemgetter(1))
  # Print the ouput
  print('--- %d n-grams over-generated n-grams indicative of output' % args.printsize)
  for k, v in scorelist[:args.printsize]:
    print('%s\t%f (ref=%d, out=%d)' % (' '.join(k), v, refall[k], outall[k]))
  print()
  print('--- %d n-grams under-generated n-grams indicative of reference' % args.printsize)
  for k, v in reversed(scorelist[-args.printsize:]):
    print('%s\t%f (ref=%d, out=%d)' % (' '.join(k), v, refall[k], outall[k]))
# Analyze the differences between two systems
else:
  raise NotImplementedError('Comparison between two systems is not implemented yet')
