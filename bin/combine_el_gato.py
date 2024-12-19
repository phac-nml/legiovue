#!/usr/bin/env python3
'''
Simple script to merge together read and assembly st's
while adding in the approach they used
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
        '-r',
        '--reads_tsv',
        type=Path,
        required=False,
        help="El_gato TSV output for reads approach"
    )
    parser.add_argument(
        '-a',
        '--assembly_tsv',
        type=Path,
        required=False,
        help="El_gato TSV output for assembly approach"
    )
    return parser


def parse_tsv_to_df(tsv: Path, approach: str) -> pd.DataFrame:
    """Parse input tsv file and add approach col

    Args:
        tsv (Path): Path to TSV file
        approach (str): Approach string to add

    Returns:
        pd.DataFrame: Dataframe from tsv file with added col
    """
    df = pd.read_csv(tsv, sep='\t')
    df['approach'] = approach
    return df


def main() -> None:
    """Entry point"""
    parser = parse_args()
    args = parser.parse_args()

    # Reads
    read_df = pd.DataFrame()
    if args.reads_tsv:
        read_df = parse_tsv_to_df(args.reads_tsv, 'reads')

    # Assemblies
    assembly_df = pd.DataFrame()
    if args.assembly_tsv:
        assembly_df = parse_tsv_to_df(args.assembly_tsv, 'assembly')

    # Make sure that assemblies take priority over reads if duplicated
    if (not assembly_df.empty) and (not read_df.empty):
        read_df = read_df[~read_df['Sample'].isin(assembly_df['Sample'])]

    # Combine, sort, output
    df = pd.concat([read_df, assembly_df], ignore_index=True)
    df.sort_values(by='Sample', inplace=True, ignore_index=True)
    df.to_csv('el_gato_st.tsv', index=False, sep='\t')

if __name__ == "__main__":
    main()
