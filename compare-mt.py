import sys
import argparse
import operator
from collections import defaultdict

parser = argparse.ArgumentParser(
    description='Program to compare MT results',
)
parser.add_argument('ref_file', type=str, help='A path to a correct reference file')
parser.add_argument('out_file', type=str, help='A path to a system output')
parser.add_argument('out2_file', nargs='?', type=str, default=None, help='A path to another system output. Add only if you want to compare outputs from two systems.')
parser.add_argument('--train_file', type=str, default=None, help='A link to the training corpus target file')
parser.add_argument('--train_counts', type=str, default=None, help='A link to the training word frequency counts as a tab-separated "word\\tfreq" file')
parser.add_argument('--alpha', type=float, default=1.0, help='A smoothing coefficient to control how much the model focuses on low- and high-frequency events. 1.0 should be fine most of the time.')
parser.add_argument('--ngram', type=int, default=4, help='Maximum length of n-grams.')
parser.add_argument('--printsize', type=int, default=50, help='How many n-grams to print.')
args = parser.parse_args()

with open(args.ref_file, "r") as f:
  ref = [line.strip().split() for line in f]
with open(args.out_file, "r") as f:
  out = [line.strip().split() for line in f]
if args.out2_file != None:
  with open(args.out2_file, "r") as f:
    out2 = [line.strip().split() for line in f]

def calc_ngrams(sent):
  ret = defaultdict(lambda: 0)
  for n in range(args.ngram):
    for i in range(len(sent)-n):
      ret[tuple(sent[i:i+n+1])] += 1
  return ret

def match_ngrams(left, right):
  ret = defaultdict(lambda: 0)
  for k, v in left.items():
    if k in right:
      ret[k] = min(v, right[k])
  return ret

# Calculate over and under-generated n-grams for two corpora
def calc_over_under(ref, out, alpha):
  # Create n-grams
  refall = defaultdict(lambda: 0)
  outall = defaultdict(lambda: 0)
  for refsent, outsent in zip(ref, out):
    for k, v in calc_ngrams(refsent).items():
      refall[k] += v
    for k, v in calc_ngrams(outsent).items():
      outall[k] += v
  # Calculate scores
  scores = {}
  for k, v in refall.items():
    scores[k] = (v + args.alpha) / (v + outall[k] + 2*args.alpha)
  for k, v in outall.items():
    scores[k] = (refall[k] + args.alpha) / (refall[k] + v + 2*args.alpha)
  return refall, outall, scores

# Calculate over and under-generated n-grams for two corpora
def calc_compare(ref, out, out2, alpha):
  outall = defaultdict(lambda: 0)
  out2all = defaultdict(lambda: 0)
  for refsent, outsent, out2sent in zip(ref, out, out2):
    refn = calc_ngrams(refsent)
    outmatch = match_ngrams(refn, calc_ngrams(outsent))
    out2match = match_ngrams(refn, calc_ngrams(out2sent))
    for k, v in outmatch.items():
      if v > out2match[k]:
        outall[k] += v - out2match[k]
    for k, v in out2match.items():
      if v > outmatch[k]:
        out2all[k] += v - outmatch[k]
  # Calculate scores
  scores = {}
  for k, v in out2all.items():
    scores[k] = (v + args.alpha) / (v + outall[k] + 2*args.alpha)
  for k, v in outall.items():
    scores[k] = (out2all[k] + args.alpha) / (out2all[k] + v + 2*args.alpha)
  return outall, out2all, scores

# Calculate the frequency counts, from the training corpus
# or training frequency file if either are specified, from the
# reference file if not
freq_counts = defaultdict(lambda: 0)
if args.train_counts != None:
  with open(args.train_counts, "r") as f:
    for line in f:
      word, freq = line.strip.split('\t')
      freq_counts[word] = freq
else:
  my_file = args.train_file if args.train_file != None else args.ref_file
  with open(args.train_counts, "r") as f:
    for line in f:
      for word in line.strip.split():
        freq_counts[word] += 1 

def calc_matches_by_freq(ref, out, buckets):
  extended_buckets = buckets + [max(freq_counts.values()) + 1]
  matches = [[0,0,0] for x in extended_buckets]
  for refsent, outsent in zip(ref, out):
    reffreq, outfreq = defaultdict(lambda: 0), defaultdict(lambda: 0)
    for x in refsent:
      reffreq[x] += 1
    for x in outsent:
      outfreq[x] += 1
    for k in set(reffreq.keys(), outfreq.keys()):
      for bucket, match in zip(extended_buckets, matches):
        if freq_counts[k] < bucket:
          match[0] += min(reffreq[k], outfreq[k])
          match[1] += reffreq[k]
          match[2] += outfreq[k]
          break 
  for bothf, reff, outf in matches:
    rec = bothf / float(reff)
    prec = bothf / float(outf)
    fmeas = 0 if bothf == 0 else 2 * prec * rec / (prec + rec)
    yield bothf, reff, outf, rec, prec, fmeas

buckets = [1, 2, 3, 4, 5, 10, 100, 1000]
bucket_strs = []
last_start = 0
for x in buckets:
  if x-1 == last_start:
    bucket_strs.append(str(last_start))
  else:
    bucket_strs.append("{}-{}".format(last_start, x-1))
  last_start = x
bucket_strs.append("{}+".format(last_start))

# Analyze the reference/output
if args.out2_file == None:
  refall, outall, scores = calc_over_under(ref, out, args.alpha)
  scorelist = sorted(scores.items(), key=operator.itemgetter(1))
  # Print the ouput
  print('--- %d over-generated n-grams indicative of output' % args.printsize)
  for k, v in scorelist[:args.printsize]:
    print('%s\t%f (ref=%d, out=%d)' % (' '.join(k), v, refall[k], outall[k]))
  print()
  print('--- %d under-generated n-grams indicative of reference' % args.printsize)
  for k, v in reversed(scorelist[-args.printsize:]):
    print('%s\t%f (ref=%d, out=%d)' % (' '.join(k), v, refall[k], outall[k]))
  # Calculate f-measure
  matches = calc_matches_by_freq(ref, out, buckets)
  print('--- word f-measure by frequency bucket')
  for bucket_str, match in zip(bucket_strs, matches):
    print("{}\t{}".format(bucket_str, match[5]))
# Analyze the differences between two systems
else:
  outall, out2all, scores = calc_compare(ref, out, out2, args.alpha)
  scorelist = sorted(scores.items(), key=operator.itemgetter(1))
  # Print the ouput
  print('--- %d n-grams that System 1 did a better job of producing' % args.printsize)
  for k, v in scorelist[:args.printsize]:
    print('%s\t%f (sys1=%d, sys2=%d)' % (' '.join(k), v, outall[k], out2all[k]))
  print()
  print('--- %d n-grams that System 2 did a better job of producing' % args.printsize)
  for k, v in reversed(scorelist[-args.printsize:]):
    print('%s\t%f (sys1=%d, sys2=%d)' % (' '.join(k), v, outall[k], out2all[k]))  
  # Calculate f-measure
  matches = calc_matches_by_freq(ref, out, buckets)
  matches2 = calc_matches_by_freq(ref, out2, buckets)
  print('--- word f-measure by frequency bucket')
  for bucket_str, match2 in zip(bucket_strs, matches, matches2):
    print("{}\t{}\t{}".format(bucket_str, match[5], match2[5]))
