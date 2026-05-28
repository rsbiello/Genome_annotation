#!/usr/bin/env python3

"""
Filter a protein FASTA file to keep only the longest isoform per gene.

This script is useful for genome annotation workflows where multiple
protein isoforms may be predicted for the same gene.

Expected input:
    A protein FASTA file where isoforms can be identified from the
    sequence ID.

Default supported ID pattern:
    gene_id-P1
    gene_id-P2
    gene_id-P3

Example FASTA IDs:
    gnl|WGS:XXXX|gene_000001-P1
    gnl|WGS:XXXX|gene_000001-P2

In this example, both proteins belong to:
    gene_000001

The script will retain only the longest protein sequence for each gene.

Usage:
    python longest_isoforms.py input.proteins.faa output.longest_isoforms.faa
"""

from Bio import SeqIO
import re
import sys


def get_gene_id(record_id):
    """
    Extract gene ID from a protein FASTA record ID.

    The default pattern captures everything before an isoform suffix
    like -P1, -P2, -P3, etc.

    Examples:
        gnl|WGS:XXXX|gene_000001-P1 -> gene_000001
        gene_000001-P2              -> gene_000001
        transcript123-P4            -> transcript123

    If your annotation uses a different naming format, edit this
    function to match your protein IDs.
    """

    # Remove everything before the final "|" if present.
    # Example:
    # gnl|WGS:XXXX|gene_000001-P1 -> gene_000001-P1
    short_id = record_id.split("|")[-1]

    # Capture gene ID before -P<number>.
    match = re.match(r"(.+)-P\d+$", short_id)

    if match:
        return match.group(1)

    return None


def main():
    if len(sys.argv) != 3:
        sys.exit(
            "Usage: python longest_isoforms.py "
            "input.proteins.faa output.longest_isoforms.faa"
        )

    input_faa = sys.argv[1]
    output_faa = sys.argv[2]

    longest = {}
    skipped = 0

    for record in SeqIO.parse(input_faa, "fasta"):
        gene_id = get_gene_id(record.id)

        if gene_id is None:
            skipped += 1
            continue

        if gene_id not in longest:
            longest[gene_id] = record
        elif len(record.seq) > len(longest[gene_id].seq):
            longest[gene_id] = record

    SeqIO.write(longest.values(), output_faa, "fasta")

    print(f"Input file: {input_faa}")
    print(f"Output file: {output_faa}")
    print(f"Retained longest isoforms for {len(longest)} genes")

    if skipped > 0:
        print(f"Warning: skipped {skipped} records because no gene ID was detected")


if __name__ == "__main__":
    main()
