#!/usr/bin/env python3
'''
Simple script to merge together a bunch of sample
qc data to create a final individual sample summary file
that can be combined at the end as a final report
'''
import argparse
import re
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
        '-br',
        '--bracken_tsv',
        type=Path,
        required=False,
        help="Bracken abundance TSV output"
    )
    parser.add_argument(
        '-tr',
        '--trimmomatic_txt',
        type=Path,
        required=False,
        help="Trimmomatic summary TXT output"
    )
    parser.add_argument(
        '-qa',
        '--quast_tsv',
        type=Path,
        required=False,
        help="Quast summary TSV output"
    )
    parser.add_argument(
        '-st',
        '--st_tsv',
        type=Path,
        required=False,
        help="Combined el_gato ST TSV output"
    )
    parser.add_argument(
        '-al',
        '--chewbbaca_stats_tsv',
        type=Path,
        required=False,
        help="Chewbbaca allele stats TSV output"
    )
    parser.add_argument(
        '-fs',
        '--final_score_csv',
        type=Path,
        required=False,
        help="Quast final score CSV output"
    )
    parser.add_argument(
        '--min_reads',
        type=int,
        required=False,
        default=150000,
        help="Minimum number of reads required to be passed through the pipeline"
    )
    parser.add_argument(
        '--min_abundance_percent',
        type=float,
        required=False,
        default=10.0,
        help="Minimum legionella pneumophila abundance from bracken output"
    )
    return parser


def grab_trim_data(file_path: Path, outdict: dict) -> dict:
    """Grab wanted data from trimmomatic summary file

    Args:
        file_path (Path): Path to trimmomatic text summary
        outdict (dict): Dict containing wanted values to add to

    Returns:
        dict: outdict
    """
    with open(file_path, 'r') as f:
        for line in f.readlines():
            line = line.strip()
            if "Both Surviving Reads:" in line:
                count = int(re.search(r'\d+', line).group(0))
                outdict['num_paired_trimmed_reads'] = count
            elif "Both Surviving Read Percent:" in line:
                pct = float(re.search(r'\d+.\d+', line).group(0))
                outdict['pct_paired_reads_passing_qc'] = pct

    return outdict


def grab_df_data(
    file_path: Path, sep: str, target: str,
    target_col: str, data_cols_dict: dict,
    outdict: dict
) -> dict:
    """Parse and grab target data from input dataframe file

    Args:
        file_path (Path): Path to input dataframe file to parse
        sep (str): Separator for dataframe file
        target (str): Target string to be used to get the needed info
        target_col (str): Target column that contains the target string
        data_cols_dict (dict): Dict that maps the input data column name to the output
            Formatted as {'Input Col Name': 'Output Col Name'}
        outdict (dict): Dict containing wanted values to add to

    Returns:
        dict: outdict
    """
    # Read in
    df = pd.read_csv(file_path, sep=sep)

    # Set df to only be the wanted target
    #  Could be the sample (most likely)
    #  or something else
    df = df[df[target_col].str.contains(f'^{target}$', regex=True) ]
    if (df.empty) or (len(df) > 1):
        return outdict

    # Get wanted values based on data_cols_dict
    for key, val in data_cols_dict.items():
        outdict[val] = df.iloc[0][key]

    return outdict


def main() -> None:
    """Entry point"""
    parser = parse_args()
    args = parser.parse_args()

    # Parse each given file to add to our outdict
    sample = str(args.sample)
    outdict = {'sample': sample}
    warn_qual_criteria = []
    failed = False
    failed_reason = []

    # Bracken
    outdict['lpn_abundance'] = 0
    if args.bracken_tsv:
        outdict = grab_df_data(
            args.bracken_tsv,
            '\t',
            'Legionella pneumophila',
            'name',
            {'fraction_total_reads': 'lpn_abundance'},
            outdict
        )
        outdict['lpn_abundance'] = round(outdict['lpn_abundance']*100, 2)

    if outdict['lpn_abundance'] < args.min_abundance_percent:
        failed = True
        failed_reason = ['no_lpn_detected']
    elif outdict['lpn_abundance'] < 75:
        warn_qual_criteria.append('low_lpn_abundance')

    # Trimmomatic
    outdict['num_paired_trimmed_reads'] = 0
    outdict['pct_paired_reads_passing_qc'] = 0
    if args.trimmomatic_txt:
        outdict = grab_trim_data(args.trimmomatic_txt, outdict)

    # Don't overwrite the failed reason as if it fails at abundance that should
    #  be reported
    if outdict['num_paired_trimmed_reads'] < args.min_reads and not failed:
        failed = True
        failed_reason = ['failing_read_count']
    elif outdict['num_paired_trimmed_reads'] < 300000:
        warn_qual_criteria.append('low_read_count')

    # Quast
    outdict['n50'] = 0
    outdict['num_contigs'] = 0
    outdict['pct_gc'] = 0
    outdict['assembly_len'] = 0
    outdict['largest_contig'] = 0
    if args.quast_tsv:
        mapping_dict = {
            'N50': 'n50',
            '# contigs': 'num_contigs',
            'GC (%)': 'pct_gc',
            'Total length (>= 0 bp)': 'assembly_len',
            'Largest contig': 'largest_contig'
        }
        outdict = grab_df_data(
            args.quast_tsv,
            '\t',
            f'{sample}.contigs',
            'Assembly',
            mapping_dict,
            outdict
        )

    if outdict['n50'] < 100000:
        warn_qual_criteria.append('low_n50')

    # ST
    outdict['st'] = 'NA'
    outdict['st_approach'] = 'NA'
    if args.st_tsv:
        mapping_dict = {
            'ST': 'st',
            'approach': 'st_approach'
        }
        outdict = grab_df_data(
            args.st_tsv,
            '\t',
            sample,
            'Sample',
            mapping_dict,
            outdict
        )

    # Chewbbaca
    outdict['chewbbaca_exc'] = 0
    outdict['chewbbaca_inf'] = 0
    outdict['chewbbaca_pct_exc'] = 0
    if args.chewbbaca_stats_tsv:
        mapping_dict = {
            'EXC': 'chewbbaca_exc',
            'INF': 'chewbbaca_inf'
        }
        outdict = grab_df_data(
            args.chewbbaca_stats_tsv,
            '\t',
            sample,
            'FILE',
            mapping_dict,
            outdict
        )
        outdict['chewbbaca_pct_exc'] = round((outdict['chewbbaca_exc'] / 1521)*100, 2)

    if outdict['chewbbaca_pct_exc'] < 90:
        warn_qual_criteria.append('low_exact_allele_calls')

    # Score CSV
    outdict['final_qc_score'] = 0
    if args.final_score_csv:
        outdict = grab_df_data(
            args.final_score_csv,
            ',',
            f'{sample}.contigs',
            'sample',
            {'final_score': 'final_qc_score'},
            outdict
        )

    if outdict['final_qc_score'] < 4:
        warn_qual_criteria.append('low_qc_score')

    # QC Checks and Final Data Cols
    qc_status = "PASS"
    if failed:
        qc_status = "FAIL"
        warn_qual_criteria = failed_reason
    elif warn_qual_criteria:
        qc_status = "WARN"

    outdict['qc_status'] = qc_status
    outdict['qc_message'] = ';'.join(warn_qual_criteria)

    df = pd.DataFrame([outdict])
    df.to_csv(f'{sample}.qc.tsv', sep='\t', index=False)


if __name__ == "__main__":
    main()
