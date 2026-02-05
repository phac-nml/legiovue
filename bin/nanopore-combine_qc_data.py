#!/usr/bin/env python3
'''
Simple script to merge together a bunch of single sample
qc data to create a final sample summary file
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
        '-pt',
        '--pretrim_nanoplot_txt',
        type=Path,
        required=False,
        help="Pretrimming Nanoplot summary TXT output"
    )
    parser.add_argument(
        '-tr',
        '--trim_nanoplot_txt',
        type=Path,
        required=False,
        help="Post Trimming Nanoplot summary TXT output"
    )
    parser.add_argument(
        '-qa',
        '--quast_tsv',
        type=Path,
        required=False,
        help="Quast summary TSV output"
    )
    parser.add_argument(
        '-as',
        '--assembly_cov_txt',
        type=Path,
        required=False,
        help="Assembly Coverage TXT output"
    )
    parser.add_argument(
        '-al',
        '--allele_cov_txt',
        type=Path,
        required=False,
        help="Allele_Coverage TXT"
    )
    parser.add_argument(
        '-ch',
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
        default=10000,
        help="Minimum number of reads required to be passed through the pipeline"
    )
    parser.add_argument(
        '--min_length',
        type=float,
        required=False,
        default=2000.0,
        help="Minimum read length required to be passed through the pipeline"
    )
    parser.add_argument(
        '--min_qual',
        type=float,
        required=False,
        default=14.0,
        help="Minimum read length required to be passed through the pipeline"
    )
    parser.add_argument(
        '--min_abundance_percent',
        type=float,
        required=False,
        default=10.0,
        help="Minimum legionella pneumophila abundance from bracken output"
    )
    parser.add_argument(
        '--outdir',
        type=Path,
        required=False,
        default='./',
        help="Output directory for final TSV file"
    )
    return parser

def grab_pretrim_data(file_path: Path, outdict: dict) -> dict:
    """Grab wanted data from Pretrim Nanoplot summary file

    Args:
        file_path (Path): Path to pretrimming Nanoplot text summary
        outdict (dict): Dict containing wanted values to add to

    Returns:
        dict: outdict
    """
    with open(file_path, 'r') as f:
        for line in f.readlines():
            line = line.strip()
            line = line.replace(",", "")
            if "Number of reads:" in line:
                num = int(re.search(r'\d+', line).group(0))
                outdict['Pretrim_Number_of_Reads'] = num
            elif "Median read length:" in line:
                length = float(re.search(r'\d+.\d+', line).group(0))
                outdict['Pretrim_Median_Read_Length'] = length
            elif "Median read quality:" in line:
                qual = float(re.search(r'\d+.\d+', line).group(0))
                outdict['Pretrim_Median_Read_Quality'] = qual
            # Handle ">Q15:" line, which is tab-delimited
            elif ">Q15:" in line:
                qual = (re.search(r'(\d+.\d+%)', line).group(0))
                outdict['Pretrim_Percent_Reads_>Q15'] = qual

    return outdict

def grab_posttrim_data(file_path: Path, outdict: dict) -> dict:
    """Grab wanted data from Post Trim Nanoplot summary file

    Args:
        file_path (Path): Path to post trimming Nanoplot text summary
        outdict (dict): Dict containing wanted values to add to

    Returns:
        dict: outdict
    """
    with open(file_path, 'r') as f:
        for line in f.readlines():
            line = line.strip()
            line = line.replace(",", "")
            if "Number of reads:" in line:
                num = int(re.search(r'\d+', line).group(0))
                outdict['Post_Trim_Number_of_Reads'] = num
            elif "Median read length:" in line:
                length = float(re.search(r'\d+.\d+', line).group(0))
                outdict['Post_Trim_Median_Read_Length'] = length
            elif "Median read quality:" in line:
                qual = float(re.search(r'\d+.\d+', line).group(0))
                outdict['Post_Trim_Median_Read_Quality'] = qual
            elif ">Q15:" in line:
                qual = (re.search(r'(\d+.\d+%)', line).group(0))
                outdict['Post_trim_Percent_Reads_>Q15'] = qual
    return outdict

def grab_assembly_data(file_path: Path, outdict: dict) -> dict:
    """Grab wanted data from assembly coverage TXT file

    Args:
        file_path (Path): Path to assembly coverage TXT file
        outdict (dict): Dict containing wanted values to add to

    Returns:
        dict: outdict
    """
    import csv  # Make sure to import the csv module

    with open(file_path, 'r') as f:
        reader = csv.DictReader(f, delimiter='\t')  # Initialize DictReader
        for row in reader:
            if row['#rname'] == 'contig00001':  # Check if the row is for a contig00001
                assembly_meandepth = float(row['meandepth'])  # Extract meandepth as float
                assembly_meanbaseq = float(row['meanbaseq'])  # Extract meanbaseq as float
                # Update outdict with the extracted values
                outdict['assembly_meandepth'] = assembly_meandepth
                outdict['assembly_meanbaseq'] = assembly_meanbaseq
    return outdict

def grab_allele_data(file_path: Path, outdict: dict) -> dict:
    """Grab wanted data from allele coverage TXT file

    Args:
        file_path (Path): Path to allele coverage TXT file
        outdict (dict): Dict containing wanted values to add to

    Returns:
        dict: outdict
    """
    import csv  # Make sure to import the csv module

    with open(file_path, 'r') as f:
        reader = csv.DictReader(f, delimiter='\t')  # Initialize DictReader
        for row in reader:
            if row['#rname'] == 'flaA':  # Check if the row is for flaA
                flaA_meandepth = float(row['meandepth'])  # Extract meandepth as float
                flaA_meanbaseq = float(row['meanbaseq'])  # Extract meanbaseq as float
                # Update outdict with the extracted values
                outdict['flaA_meandepth'] = flaA_meandepth
                outdict['flaA_meanbaseq'] = flaA_meanbaseq

            elif row['#rname'] == 'pilE':  # Check if the row is for pilE
                pilE_meandepth = float(row['meandepth'])  # Extract meandepth as float
                pilE_meanbaseq = float(row['meanbaseq'])  # Extract meanbaseq as float
                # Update outdict with the extracted values
                outdict['pilE_meandepth'] = pilE_meandepth
                outdict['pilE_meanbaseq'] = pilE_meanbaseq

            elif row['#rname'] == 'asd':  # Check if the row is for asd
                asd_meandepth = float(row['meandepth'])  # Extract meandepth as float
                asd_meanbaseq = float(row['meanbaseq'])  # Extract meanbaseq as float
                # Update outdict with the extracted values
                outdict['asd_meandepth'] = asd_meandepth
                outdict['asd_meanbaseq'] = asd_meanbaseq
            
            elif row['#rname'] == 'mip':  # Check if the row is for mip
                mip_meandepth = float(row['meandepth'])  # Extract meandepth as float
                mip_meanbaseq = float(row['meanbaseq'])  # Extract meanbaseq as float
                # Update outdict with the extracted values
                outdict['mip_meandepth'] = mip_meandepth
                outdict['mip_meanbaseq'] = mip_meanbaseq

            elif row['#rname'] == 'mompS':  # Check if the row is for mompS
                mompS_meandepth = float(row['meandepth'])  # Extract meandepth as float
                mompS_meanbaseq = float(row['meanbaseq'])  # Extract meanbaseq as float
                # Update outdict with the extracted values
                outdict['mompS_meandepth'] = mompS_meandepth
                outdict['mompS_meanbaseq'] = mompS_meanbaseq

            elif row['#rname'] == 'proA':  # Check if the row is for proA
                proA_meandepth = float(row['meandepth'])  # Extract meandepth as float
                proA_meanbaseq = float(row['meanbaseq'])  # Extract meanbaseq as float
                # Update outdict with the extracted values
                outdict['proA_meandepth'] = proA_meandepth
                outdict['proA_meanbaseq'] = proA_meanbaseq

            elif row['#rname'] == 'neuA_neuAH':  # Check if the row is for neuA_neuAH
                neuA_neuAh_meandepth = float(row['meandepth'])  # Extract meandepth as float
                neuA_neuAh_meanbaseq = float(row['meanbaseq'])  # Extract meanbaseq as float
                # Update outdict with the extracted values
                outdict['neuA_neuAh_meandepth'] = neuA_neuAh_meandepth
                outdict['neuA_neuAh_meanbaseq'] = neuA_neuAh_meanbaseq
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
    # Ensure all values in the target column are strings
    df[target_col] = df[target_col].fillna('').astype(str)
    # Now apply the string operation safely
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

    # Check for existance
    outdir = Path(args.outdir)
    if not outdir.exists() or not outdir.is_dir():
        raise ValueError('Input out directory {args.outdir} does not exist')
    
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
    
    # Pre Trimming Nanoplot
    outdict['Pretrim_Number_of_Reads'] = 0
    outdict['Pretrim_Median_Read_Length'] = 0
    outdict['Pretrim_Median_Read_Quality'] = 0
    outdict['Pretrim_Percent_Reads_>Q15'] = 0
    if args.pretrim_nanoplot_txt:
        outdict = grab_pretrim_data(args.pretrim_nanoplot_txt, outdict)

    # Post Trimming Nanoplot
    outdict['Post_Trim_Number_of_Reads'] = 0
    outdict['Post_Trim_Median_Read_Length'] = 0
    outdict['Post_Trim_Median_Read_Quality'] = 0
    outdict['Post_trim_Percent_Reads_>Q15'] = 0
    if args.trim_nanoplot_txt:
        outdict = grab_posttrim_data(args.trim_nanoplot_txt, outdict)

        if outdict['Post_Trim_Number_of_Reads'] < args.min_reads:
            failed = True
            failed_reason = ['failing_read_count']
        elif outdict['Post_Trim_Number_of_Reads'] < 30000:
            warn_qual_criteria.append('low_read_count')

        if outdict['Post_Trim_Median_Read_Length'] < args.min_length:
            failed = True
            failed_reason = ['failing_read_length']
        elif outdict['Post_Trim_Median_Read_Length'] < 4000.0:
            warn_qual_criteria.append('low_read_length')

        if outdict['Post_Trim_Median_Read_Quality'] < args.min_qual:
            failed = True
            failed_reason = ['failing_read_quality']
        elif outdict['Post_Trim_Median_Read_Quality'] < 17.0:
            warn_qual_criteria.append('low_read_quality')

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
            f'{sample}_',
            'Assembly',
            mapping_dict,
            outdict
        )

        if outdict['n50'] < 100000:
            warn_qual_criteria.append('low_n50')

    # Assembly Coverage
    outdict['assembly_meandepth'] = 0
    outdict['assembly_meanbaseq'] = 0
    if args.assembly_cov_txt:
        outdict = grab_assembly_data(args.assembly_cov_txt, outdict)

        if outdict['assembly_meandepth'] < 15:
            failed = True
            failed_reason = ['failing_assembly_meandepth']
        elif outdict['assembly_meandepth'] < 30:
            warn_qual_criteria.append('low_assembly_meandepth')

        if outdict['assembly_meanbaseq'] < 30:
            failed = True
            failed_reason = ['failing_assembly_meanbaseq']
        elif outdict['assembly_meanbaseq'] < 35:
            warn_qual_criteria.append('low_assembly_meanbaseq')

    # Allele Coverage
    outdict['flaA_meandepth'] = 0
    outdict['flaA_meanbaseq'] = 0
    outdict['pilE_meandepth'] = 0
    outdict['pilE_meanbaseq'] = 0
    outdict['asd_meandepth'] = 0
    outdict['asd_meanbaseq'] = 0
    outdict['mip_meandepth'] = 0
    outdict['mip_meanbaseq'] = 0
    outdict['mompS_meandepth'] = 0
    outdict['mompS_meanbaseq'] = 0
    outdict['proA_meandepth'] = 0
    outdict['proA_meanbaseq'] = 0
    outdict['neuA_neuAh_meandepth'] = 0
    outdict['neuA_neuAh_meanbaseq'] = 0
    if args.allele_cov_txt:
        outdict = grab_allele_data(args.allele_cov_txt, outdict)

        if outdict['flaA_meandepth'] < 10:
            failed = True
            failed_reason = ['failing_flaA_meandepth']
        elif outdict['flaA_meandepth'] < 20:
            warn_qual_criteria.append('low_flaA_meandepth')

        if outdict['flaA_meanbaseq'] < 30:
            failed = True
            failed_reason = ['failing_flaA_meanbaseq']
        elif outdict['flaA_meanbaseq'] < 35:
            warn_qual_criteria.append('low_flaA_meanbaseq')

        if outdict['pilE_meandepth'] < 10:
            failed = True
            failed_reason = ['failing_pilE_meandepth']
        elif outdict['pilE_meandepth'] < 20:
            warn_qual_criteria.append('low_pilE_meandepth')

        if outdict['pilE_meanbaseq'] < 30:
            failed = True
            failed_reason = ['failing_pilE_meanbaseq']
        elif outdict['pilE_meanbaseq'] < 35:
            warn_qual_criteria.append('low_pilE_meanbaseq')

        if outdict['asd_meandepth'] < 10:
            failed = True
            failed_reason = ['failing_asd_meandepth']
        elif outdict['asd_meandepth'] < 20:
            warn_qual_criteria.append('low_asd_meandepth')

        if outdict['asd_meanbaseq'] < 30:
            failed = True
            failed_reason = ['failing_asd_meanbaseq']
        elif outdict['asd_meanbaseq'] < 35:
            warn_qual_criteria.append('low_asd_meanbaseq') 

        if outdict['mip_meandepth'] < 10:
            failed = True
            failed_reason = ['failing_mip_meandepth']
        elif outdict['mip_meandepth'] < 20:
            warn_qual_criteria.append('low_mip_meandepth')

        if outdict['mip_meanbaseq'] < 30:
            failed = True
            failed_reason = ['failing_mip_meanbaseq']
        elif outdict['mip_meanbaseq'] < 35:
            warn_qual_criteria.append('low_mip_meanbaseq')

        if outdict['mompS_meandepth'] < 10:
            failed = True
            failed_reason = ['failing_mompS_meandepth']
        elif outdict['mompS_meandepth'] < 20:
            warn_qual_criteria.append('low_mompS_meandepth')

        if outdict['mompS_meanbaseq'] < 30:
            failed = True
            failed_reason = ['failing_mompS_meanbaseq']
        elif outdict['mompS_meanbaseq'] < 35:
            warn_qual_criteria.append('low_mompS_meanbaseq')

        if outdict['proA_meandepth'] < 10:
            failed = True
            failed_reason = ['failing_proA_meandepth']
        elif outdict['proA_meandepth'] < 20:
            warn_qual_criteria.append('low_proA_meandepth')

        if outdict['proA_meanbaseq'] < 30:
            failed = True
            failed_reason = ['failing_proA_meanbaseq']
        elif outdict['proA_meanbaseq'] < 35:
            warn_qual_criteria.append('low_proA_meanbaseq')

        if outdict['neuA_neuAh_meandepth'] < 10:
            failed = True
            failed_reason = ['failing_neuA_neuAh_meandepth']
        elif outdict['neuA_neuAh_meandepth'] < 20:
            warn_qual_criteria.append('low_neuA_neuAh_meandepth')

        if outdict['neuA_neuAh_meanbaseq'] < 30:
            failed = True
            failed_reason = ['failing_neuA_neuAh_meanbaseq']
        elif outdict['neuA_neuAh_meanbaseq'] < 35:
            warn_qual_criteria.append('low_neuA_neuAh_meanbaseq')

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
            f'{sample}_',
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
    outfile = outdir / f'{sample}.qc.tsv'
    df.to_csv(outfile, sep='\t', index=False)


if __name__ == "__main__":
    main()
