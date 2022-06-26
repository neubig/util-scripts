from __future__ import annotations

import argparse
import random

"""
What's this?
------------

This script allows you to combine multiple MT system outputs into a format
suitable for manual evaluation. It should be used in combination with
syseval-report.py.

Usage and Data Format
---------------------

syseval-combine.pl               \
           -src test.src         \
           -ref test.trg         \
           -ids output.ids       \
           -min 1                \
           -max 30               \
           system-1.trg system-2.trg system-3.trg ... \
           > output.csv

Where test.src is the input, test.trg is the reference, output.ids is a
list of ids used in syseval-report.pl. -min and -max are the minimum and
maximum length of sentences to use in evaluation, and system-1.trg,
system-2.trg, etc. are system output files. output.txt will be output in
tab-separated format for reading into spreadsheet software such as Excel or
OpenOffice Calc.

Note that the output will be a tab-separated file with the reference and
source first, followed by a system output and a blank space for entering
its rating. The order of the system outputs will be randomized to prevent
any effect of ordering on the decisions, and also identical hypotheses will
be combined so the rater does not need to grade the same sentence twice.
This order is saved in the output.ids file, and can be restored after the
manual evaluation is finished by syseval-report.py.
"""

def load_lines(fname: str) -> list[str]:
    with open(fname, 'r') as fin:
        return [x.strip() for x in fin]

def print_line(src: str, ref: str | None, hyp: str, rating: str, file):
    if ref:
        print(f'{src}\t{ref}\t{hyp}\t{rating}', file=file)
    else:
        print(f'{src}\t{hyp}\t{rating}', file=file)

def main():

    # Make parser object
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)

    p.add_argument("--src", help="the source file")
    p.add_argument("--ref", required=False, help="the reference file")
    p.add_argument("--hyps", nargs="+", help="the hypotheses")
    p.add_argument("--min", default=0, help="the minimum sentence length")
    p.add_argument("--max", default=10000, help="the maximum sentence length")
    p.add_argument("--lines", default=None, help="the number of lines to print out")
    p.add_argument("--ids_out", help="the file to write IDs to")
    p.add_argument("--tsv_out", help="the file to write the tsv to")
    args = p.parse_args()

    src_lines = load_lines(args.src)
    ref_lines = load_lines(args.ref) if args.ref else None
    hyps_lines = [load_lines(x) for x in args.hyps]

    if not all([len(x) == len(src_lines) for x in hyps_lines]):
        raise ValueError(
            f'src and hyp lines don\'t match ({len(src_lines)} != {[len(x) for x in hyps_lines]})')
    if ref_lines and len(ref_lines) != len(src_lines):
        raise ValueError(f'src and ref lines don\'t match ({len(src_lines)} != {len(ref_lines)})')

    valid_ids = []
    for i, src_line in enumerate(src_lines):
        src_len = len(' '.split(src_line))
        if src_len >= args.min and src_len <= args.max:
            valid_ids.append(i)
    random.shuffle(valid_ids)
    if args.lines and args.lines < valid_ids:
        valid_ids = valid_ids[:args.lines]

    with open(args.tsv_out, 'w') as tsv_out, open(args.ids_out, 'w') as ids_out:
        print_line('Source', 'Reference' if args.ref else None, 'Translation', 'Rating', tsv_out)
        for i in valid_ids:
            hyps_line = [x[i] for x in hyps_lines]
            dedup_line = list(set(hyps_line))
            random.shuffle(dedup_line)
            dedup_map = {v: str(i) for i, v in enumerate(dedup_line)}
            hyps_ids = [dedup_map[x] for x in hyps_line]
            ref_line = ref_lines[i] if ref_lines else None
            print('\t'.join(hyps_ids), file=ids_out)
            print_line(src_lines[i], ref_line, dedup_line[0], 'XXX', tsv_out)
            for x in dedup_line[1:]:
                print_line('', ' ' if ref_lines else None, x, 'XXX', tsv_out)
            print('', file=tsv_out)

if __name__ == '__main__':
    main()