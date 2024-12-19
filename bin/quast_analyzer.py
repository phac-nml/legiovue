#!/usr/bin/env python3
"""
Analyze quast transposed results TSV file
according to provided specifications
"""
import argparse
import csv
import logging
import os

# Log
logger = logging.getLogger('quast_analyzer_main')
version = '0.1.0'

# Calculated Constants (fixed values to compare with)
#  Based on 121 Complete RefSeq Genomes for *L. pneumophila*
#  accessed and calculated on Oct.23rd, 2024
GC_AVG = 38.44
GC_STDEV = 0.165
ASSEMBLY_AVG = 3459184
ASSEMBLY_STDEV = 130839

# Score dict
score_word_dict = {
    0: 'poor',
    1: 'poor',
    2: 'unideal',
    3: 'moderate',
    4: 'passing',
    5: 'good',
    6: 'excellent'
}

def init_parser() -> argparse.ArgumentParser:
    """Create parser from command line arguments

    Returns:
        argparse.ArgumentParser: Parser
    """
    parser = argparse.ArgumentParser(prog='quast_analyzer', description='Analyze quast results and output the comparison.')
    # Input/Output Options
    parser.add_argument(
        'input_file',
        help='Path to the input transposed_report.tsv file'
    )

    # Outputs
    parser.add_argument(
        '-o',
        '--outfile',
        default='scored_quast_report.csv',
        type=str,
        help='Output CSV filename. Default is scored_quast_report.csv'
    )
    parser.add_argument(
        '--force',
        required=False,
        default=False,
        action='store_true',
        help='Force overwrite of existing output data'
    )

    # QC Threshold Options
    parser.add_argument(
        '--max_contigs',
        type=int,
        default=100,
        help='Threshold for the number of contigs > 500bp assembled by SPAdes'
    )
    parser.add_argument(
        '--min_align_percent',
        type=int,
        default=75,
        help='Thresold for minimum quast genome fraction percentage'
    )
    
    # Version #
    parser.add_argument(
        '-v',
        '--version',
        help='Outputs the current version',
        action='version',
        version='%(prog)s {}'.format(version)
    )
    return parser


def parse_header_line(header_line: str) -> list:
    """Parse tab-separated header line into a list

    Args:
        header_line (str): Header line string

    Returns:
        list: Split header line by tabs
    """
    return header_line.strip().split('\t')


def parse_sample_line(sample_line: str, headers: list) -> dict:
    """Split sample line string into key-val dict based on headers

    Args:
        sample_line (str): Tab separated sample data line 
        headers (list): List of headers

    Returns:
        dict: Key-val dict with the headers as keys
    """
    fields = sample_line.strip().split('\t')
    return dict(zip(headers, fields))


def calculate_score(metric: int, bottom=100000, top=300000):
    """Calculate variable score based on a bottom and top range

    Args:
        metric (int): Metric to score
        bottom (int, optional): Bottom of the score range. Defaults to 100000.
        top (int, optional): Top of the score range. Defaults to 300000.

    Returns:
        float: 2-digit calculated score between 0-1
    """
    # Best/Worst Scores
    if metric <= bottom:
        return 0.0
    elif metric >= top:
        return 1.0
    # Calculation
    return round((metric - bottom) / (top - bottom), 2)


def analyze_sample(sample: dict, max_contigs: int, min_align_percent: int) -> dict:
    """Extract and values from the sample dictionary

    Args:
        sample (dict): Dictionary containing all sample values from quast input line
        max_contigs (int): Max contigs to allow before failing criteria
        min_align_percent (int): Minimum align percentage allowed before failing criteria

    Returns:
        dict: Sample scoring dict
    """
    sample_name = sample.get('Assembly', 'Unknown')
    try:
        num_contigs = int(sample.get('# contigs', '0'))
        n50 = int(sample.get('N50', '0'))
        dup_ratio = float(sample.get('Duplication ratio', '0.0'))
        align_perc = float(sample.get('Genome fraction (%)', '0.0'))
        gc_content = float(sample.get('GC (%)', '0.0'))
        assembly_length = int(sample.get("Total length (>= 0 bp)", '0'))
    except ValueError:
        logger.warning("Invalid data format for sample: %s", sample_name)
        return None

    # Initialize variables for scoring
    score = 0

    logger.info("Starting analysis for sample: %s", sample_name)

    # Evaluate "# contigs"
    num_contigs_score = 0
    if num_contigs <= max_contigs:
        score += 1
        num_contigs_score = 1

    # Evaluate "N50"
    n50_score = calculate_score(n50)
    score += n50_score

    # Evaluate "Duplication ratio"
    dup_ratio_score = 0
    if 1 <= dup_ratio <= 1.3:
        score += 1
        dup_ratio_score = 1

    # Alignment percentage (25% misalignment threshold = 100-25 = 75% alignment threshold)
    alignment_score = 0
    if align_perc >= min_align_percent:
        score += 1
        alignment_score = 1

    # GC content
    gc_content_score = 0
    if (GC_AVG - (2 * GC_STDEV)) < gc_content < (GC_AVG + (2 * GC_STDEV)):
        score += 1
        gc_content_score = 1

    # Total Assembly Length
    assembly_length_score = 0
    if (ASSEMBLY_AVG - (2 * ASSEMBLY_STDEV)) < assembly_length < (ASSEMBLY_AVG + (2 * ASSEMBLY_STDEV)):
        score += 1
        assembly_length_score = 1

    # Get word score rating
    score_rating = score_word_dict[round(score, 0)]

    logger.info(
        "Finished analysis for sample: %s with final score and rating: %s/6 %s",
        sample_name, score, score_rating
    )

    return {
        "sample": sample_name,
        "num_contigs": num_contigs_score,
        "N50": n50_score,
        "duplication_ratio": dup_ratio_score,
        "percent_alignment": alignment_score,
        "assembly_length": assembly_length_score,
        "GC_content": gc_content_score,
        "final_score": score,
        "score_rating": score_rating
    }


def main() -> None:
    """Main script entry point"""
    ## Args and Checks ##
    # Parse command-line arguments
    parser = init_parser()
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s %(levelname)s: %(message)s'
    )

    # Ensure the file paths are correct whether they're absolute or relative
    input_file = os.path.abspath(args.input_file)
    output_file = os.path.abspath(args.outfile)
    outdir = os.path.split(output_file)[0]

    # Check if the input file exists
    if not os.path.exists(input_file):
        logger.error("The input file '%s' could not be found", args.input_file)
        raise RuntimeError(f"Input file '{args.input_file}' was not found")

    # Check if the output directory exists
    if not os.path.isdir(outdir):
        logger.error("The output directory path given '%s' could not be found", outdir)
        raise RuntimeError(f"The output directory path '{outdir}' could not be found")

    # Check if file already exists
    if os.path.exists(output_file):
        if not args.force:
            logger.error("Output file '%s' exists. Pass '--force' to overwrite", output_file)
            raise RuntimeError(f"Output file '{output_file}' exists")

    ## Output Setup ##
    results_list = []

    ## Read in Data and Analyze ##
    with open(input_file, 'r') as f:
        # Read the header line to get column names
        header_line = f.readline().strip()
        headers = parse_header_line(header_line)

        # Read each sample line and give a score
        for line in f:
            sample_data = parse_sample_line(line.strip(), headers)

            # Analyze the sample and append the result
            result = analyze_sample(sample_data, args.max_contigs, args.min_align_percent)
            if result:
                results_list.append(result)

    # Write the output file
    with open(output_file, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=result.keys())

        writer.writeheader()
        for result in results_list:
            writer.writerow(result)

    logger.info("Program completed. Results saved to %s", output_file)


if __name__ == "__main__":
    main()
