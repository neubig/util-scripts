import sys

import numpy as np

"""
What's this?
------------

Given a TSV-format manual evaluation file created by syseval-combine.py,
this script restores the orders of the systems and calculates an average
score for each system.

Usage and Data Format
---------------------

syseval-report.py finished-eval.tsv output.ids

Where finished-eval is a completely filled in manual evaluation TSV file
and output.ids is the ID file output by syseval-combine.pl
"""

with open(sys.argv[1], 'r') as tsv_in, open(sys.argv[2], 'r') as ids_in:
    header = next(tsv_in).split('\t')
    if header[0] != 'Source':
        raise ValueError(f'Illegal header {header}')
    has_reference = 1 if header[1] == 'Reference' else 0
    parsed_tsv = []
    curr_data = {}
    for line in tsv_in:
        cols = [x.strip() for x in line.split('\t')]
        if len(cols) > 1:
            if 'src' not in curr_data:
                curr_data['src'] = cols[0]
                if has_reference:
                    curr_data['ref'] = cols[1]
                curr_data['hyps'] = []
                curr_data['scores'] = []
            curr_data['hyps'].append(cols[1+has_reference])
            curr_data['scores'].append(cols[2+has_reference])
        else:
            parsed_tsv.append(curr_data)
            curr_data = {}
    all_scores = None
    for ids_str, data in zip(ids_in, parsed_tsv):
        ids = [int(x) for x in ids_str.strip().split('\t')]
        if not all_scores:
            all_scores = [list() for _ in ids]
        my_hyps = [data['hyps'][i] for i in ids]
        my_scores = [data['scores'][i] for i in ids]
        out_cols = [data['src']]
        if 'ref' in data:
            out_cols.append(data['ref'])
        for i, (hyp, score) in enumerate(zip(my_hyps, my_scores)):
            out_cols += [hyp, score]
            try:
                all_scores[i].append(float(score))
            except:
                print(f'WARNING: illegal score {score}', file=sys.stderr)
        print('\t'.join(out_cols))
    avg_scores = [str(np.average(x)) for x in all_scores]
    print('\n--- Average Scores ---\n'+'\t'.join(avg_scores))

