######################################################################
# Compare two systems using bootstrap resampling                     #
#  * by Graham Neubig                                                #
#  * minor modifications by Mathias Müller                           #
#                                                                    #
# See, e.g. the following paper for references                       #
#                                                                    #
# Statistical Significance Tests for Machine Translation Evaluation  #
# Philipp Koehn                                                      #
# http://www.aclweb.org/anthology/W04-3250                           #
#                                                                    #
######################################################################

import numpy as np


EVAL_TYPE_ACC = "acc"
EVAL_TYPE_BLEU = "bleu"
EVAL_TYPE_BLEU_DETOK = "bleu_detok"
EVAL_TYPE_PEARSON = "pearson"

EVAL_TYPES = [EVAL_TYPE_ACC,
              EVAL_TYPE_BLEU,
              EVAL_TYPE_BLEU_DETOK,
              EVAL_TYPE_PEARSON]


def eval_preproc(data, eval_type='acc'):
  ''' Preprocess into the appropriate format for a particular evaluation type '''
  if type(data) == str:
    data = data.strip()
    if eval_type == EVAL_TYPE_BLEU:
      data = data.split()
    elif eval_type == EVAL_TYPE_PEARSON:
      data = float(data)
  return data

def eval_measure(gold, sys, eval_type='acc'):
  ''' Evaluation measure
  
  This takes in gold labels and system outputs and evaluates their
  accuracy. It currently supports:
  * Accuracy (acc), percentage of labels that match
  * Pearson's correlation coefficient (pearson)
  * BLEU score (bleu)
  * BLEU_detok, on detokenized references and translations, with internal tokenization

  :param gold: the correct labels
  :param sys: the system outputs
  :param eval_type: The type of evaluation to do (acc, pearson, bleu, bleu_detok)
  '''
  if eval_type == EVAL_TYPE_ACC:
    return sum([1 if g == s else 0 for g, s in zip(gold, sys)]) / float(len(gold))
  elif eval_type == EVAL_TYPE_BLEU:
    import nltk
    gold_wrap = [[x] for x in gold]
    return nltk.translate.bleu_score.corpus_bleu(gold_wrap, sys)
  elif eval_type == EVAL_TYPE_PEARSON:
    return np.corrcoef([gold, sys])[0,1]
  elif eval_type == EVAL_TYPE_BLEU_DETOK:
    import sacrebleu
    # make sure score is 0-based instead of 100-based
    return sacrebleu.corpus_bleu(sys, [gold]).score / 100.
  else:
    raise NotImplementedError('Unknown eval type in eval_measure: %s' % eval_type)

def eval_with_paired_bootstrap(gold, sys1, sys2,
                               num_samples=10000, sample_ratio=0.5,
                               eval_type='acc'):
  ''' Evaluate with paired boostrap

  This compares two systems, performing a significance tests with
  paired bootstrap resampling to compare the accuracy of the two systems.
  
  :param gold: The correct labels
  :param sys1: The output of system 1
  :param sys2: The output of system 2
  :param num_samples: The number of bootstrap samples to take
  :param sample_ratio: The ratio of samples to take every time
  :param eval_type: The type of evaluation to do (acc, pearson, bleu, bleu_detok)
  '''
  assert(len(gold) == len(sys1))
  assert(len(gold) == len(sys2))
  
  # Preprocess the data appropriately for they type of eval
  gold = [eval_preproc(x, eval_type) for x in gold]
  sys1 = [eval_preproc(x, eval_type) for x in sys1]
  sys2 = [eval_preproc(x, eval_type) for x in sys2]

  sys1_scores = []
  sys2_scores = []
  wins = [0, 0, 0]
  n = len(gold)
  ids = list(range(n))

  for _ in range(num_samples):
    # Subsample the gold and system outputs
    np.random.shuffle(ids)
    reduced_ids = ids[:int(len(ids)*sample_ratio)]
    reduced_gold = [gold[i] for i in reduced_ids]
    reduced_sys1 = [sys1[i] for i in reduced_ids]
    reduced_sys2 = [sys2[i] for i in reduced_ids]
    # Calculate accuracy on the reduced sample and save stats
    sys1_score = eval_measure(reduced_gold, reduced_sys1, eval_type=eval_type)
    sys2_score = eval_measure(reduced_gold, reduced_sys2, eval_type=eval_type)
    if sys1_score > sys2_score:
      wins[0] += 1
    elif sys1_score < sys2_score:
      wins[1] += 1
    else:
      wins[2] += 1
    sys1_scores.append(sys1_score)
    sys2_scores.append(sys2_score)

  # Print win stats
  wins = [x/float(num_samples) for x in wins]
  print('Win ratio: sys1=%.3f, sys2=%.3f, tie=%.3f' % (wins[0], wins[1], wins[2]))
  if wins[0] > wins[1]:
    print('(sys1 is superior with p value p=%.3f)\n' % (1-wins[0]))
  elif wins[1] > wins[0]:
    print('(sys2 is superior with p value p=%.3f)\n' % (1-wins[1]))

  # Print system stats
  sys1_scores.sort()
  sys2_scores.sort()
  print('sys1 mean=%.3f, median=%.3f, 95%% confidence interval=[%.3f, %.3f]' %
          (np.mean(sys1_scores), np.median(sys1_scores), sys1_scores[int(num_samples * 0.025)], sys1_scores[int(num_samples * 0.975)]))
  print('sys2 mean=%.3f, median=%.3f, 95%% confidence interval=[%.3f, %.3f]' %
          (np.mean(sys2_scores), np.median(sys2_scores), sys2_scores[int(num_samples * 0.025)], sys2_scores[int(num_samples * 0.975)]))

if __name__ == "__main__":
  # execute only if run as a script
  import argparse
  parser = argparse.ArgumentParser()
  parser.add_argument('gold', help='File of the correct answers')
  parser.add_argument('sys1', help='File of the answers for system 1')
  parser.add_argument('sys2', help='File of the answers for system 2')
  parser.add_argument('--eval_type', help='The evaluation type (acc/pearson/bleu/bleu_detok)', type=str, default='acc', choices=EVAL_TYPES)
  parser.add_argument('--num_samples', help='Number of samples to use', type=int, default=10000)
  args = parser.parse_args()
  
  with open(args.gold, 'r') as f:
    gold = f.readlines() 
  with open(args.sys1, 'r') as f:
    sys1 = f.readlines() 
  with open(args.sys2, 'r') as f:
    sys2 = f.readlines() 
  eval_with_paired_bootstrap(gold, sys1, sys2, eval_type=args.eval_type, num_samples=args.num_samples)
