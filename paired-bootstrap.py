######################################################################
# Compare two systems using bootstrap resampling                     #
#  by Graham Neubig                                                  #
#                                                                    #
# See, e.g. the following paper for references                       #
#                                                                    #
# Statistical Significance Tests for Machine Translation Evaluation  #
# Philipp Koehn                                                      #
# http://www.aclweb.org/anthology/W04-3250                           #
#                                                                    #
######################################################################

import np

def eval_measure(gold, sys):
  ''' Evaluation measure
  
  This takes in gold labels and system outputs and evaluates their
  accuracy. It currently just measures the ratio of labels that are
  correct, but it can be modified to be any arbitrary evaluation function
  (e.g. F-measure, BLEU score, etc.)

  :param gold: the correct labels
  :param sys: the system outputs
  '''
  return sum([1 if g == s else 0 for g, s in zip(gold, sys)]) / float(len(gold))

def eval_with_paired_bootstrap(gold, sys1, sys2,
                               num_samples=10000, sample_ratio=0.5):
  ''' Evaluate with paired boostrap

  This compares two systems, performing a signifiance tests with
  paired bootstrap resampling to compare the accuracy of the two systems.
  
  :param gold: The correct labels
  :param sys1: The output of system 1
  :param sys2: The output of system 2
  :param num_samples: The number of bootstrap samples to take
  :param sample_ratio: The ratio of samples to take every time
  '''
  assert(len(gold) == len(sys1))
  assert(len(gold) == len(sys2))
  
  sys1_scores = []
  sys2_scores = []
  wins = [0, 0, 0]
  n = len(gold)
  ids = range(n)

  for _ in range(num_samples):
    # Subsample the gold and system outputs
    np.random.shuffle(ids)
    reduced_ids = ids[:int(len(ids)*sample_ratio)]
    reduced_gold = [gold[i] for i in reduced_ids]
    reduced_sys1 = [sys1[i] for i in reduced_ids]
    reduced_sys2 = [sys2[i] for i in reduced_ids]
    # Calculate accuracy on the reduced sample and save stats
    sys1_score = eval_measure(reduced_gold, reduced_sys1)
    sys2_score = eval_measure(reduced_gold, reduced_sys2)
    if sys1_score > sys2_score:
      wins[0] += 1
    if sys1_score < sys2_score:
      wins[1] += 1
    else:
      wins[2] += 1
    sys1_scores.append(sys1_score)
    sys2_scores.append(sys2_score)

  # Print win stats
  wins = [x/float(num_samples) for x in wins]
  print('Win ratio: sys1=%.3f, sys2=%.3f, tie=%.3f' % (wins[0], wins[1], wins[2]))
  if sys1 > sys2:
    print('(sys1 is superior at significance threshold p=%.3f)\n' % wins[0])
  elif sys2 > sys1:
    print('(sys2 is superior at significance threshold p=%.3f)\n' % wins[1])

  # Print system stats
  sys1_scores.sort()
  sys2_scores.sort()
  print('sys1 mean=%.3f, median=%.3f, 95%% confidence interval=[%.3f, %.3f]' %
          np.mean(sys1_scores), np.median(sys1_scores), sys1_scores[int(n * 0.025)], sys1_scores[int(n * 0.975)])
  print('sys2 mean=%.3f, median=%.3f, 95%% confidence interval=[%.3f, %.3f]' %
          np.mean(sys2_scores), np.median(sys2_scores), sys2_scores[int(n * 0.025)], sys2_scores[int(n * 0.975)])

