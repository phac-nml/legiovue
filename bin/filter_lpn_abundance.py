#!/usr/bin/env python3
'''
Simple helper script to check that Bracken Lpn abundance
is above the required input threshold

In the future we may want to include this as part of the 
nextflow/groovy script over it being a full process but
with development time it is here for now
'''
import argparse
import pandas as pd

from pathlib import Path

def parse_args() -> argparse.ArgumentParser:
    """Parse cl args and create parser

    Returns:
        argparse.ArgumentParser: Parsed args
    """
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-s',
        '--sample',
        type=str,
        required=True,
        help="The sample name"
    )
    parser.add_argument(
        '-b',
        '--bracken_tsv',
        type=Path,
        required=False,
        help="Bracken abundance TSV output"
    )
    parser.add_argument(
        '-t',
        '--threshold',
        type=float,
        required=False,
        default=10.0,
        help="Threshold to fail and kick sample out of pipeline"
    )
    return parser

def main() -> None:
    """Entry point"""
    parser = parse_args()
    args = parser.parse_args()

    # Check for Lpn abundance hitting threshold
    df = pd.read_csv(args.bracken_tsv, sep='\t')

    # See if we have Legionella pneumophila
    #  Empty file means that we've also failed
    passing = 'YES'
    df = df[df['name'].str.contains('Legionella pneumophila') ]
    if (df.empty) or (len(df) > 1):
        passing = 'NO'
    elif df.iloc[0]['fraction_total_reads']*100 < args.threshold:
        passing = 'NO'

    outdf = pd.DataFrame({'sample': [args.sample], 'pass': [passing]})
    outdf.to_csv(f'{args.sample}.check.csv', index=False)

if __name__ == "__main__":
    main()
