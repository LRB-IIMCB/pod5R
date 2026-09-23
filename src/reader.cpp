#!/usr/bin/env python3

import argparse
import sys
import requests


ENA_SEARCH = "https://www.ebi.ac.uk/ena/portal/api/search"


def main():
  print("SCRIPT STARTED", flush=True)

  parser = argparse.ArgumentParser()
  parser.add_argument(
    "taxid",
    type=int,
    help="NCBI taxonomy ID, e.g. 10090 for Mus musculus"
  )
  parser.add_argument(
    "-o",
    "--output",
    default="ena_ont.tsv"
  )

  args = parser.parse_args()

  print(f"Tax ID: {args.taxid}", flush=True)
  print("Contacting ENA...", flush=True)

  query = (
    f"tax_tree({args.taxid}) AND "
'instrument_platform="OXFORD_NANOPORE"'
  )

  params = {
    "result": "read_run",
    "query": query,
    "fields": (
        "run_accession,"
        "study_accession,"
        "sample_accession,"
        "scientific_name,"
        "tax_id,"
        "instrument_model,"
        "submitted_format,"
        "submitted_ftp,"
        "submitted_bytes,"
        "submitted_md5"
    ),
    "format": "tsv",
    "limit": 0,
  }

try:
  r = requests.get(
    ENA_SEARCH,
    params=params,
    timeout=120
  )
  except Exception as e:
  print(
    f"ERROR contacting ENA: {e}",
    file=sys.stderr,
    flush=True
  )
  sys.exit(1)

  print(
    f"HTTP status: {r.status_code}",
    flush=True
  )

  print(
    f"ENA URL:\n{r.url}",
    flush=True
  )

  if not r.ok:
    print(
      "\nENA returned an error:",
      file=sys.stderr
    )
    print(
      r.text[:5000],
            file=sys.stderr
    )
    sys.exit(1)

    print(
      f"Downloaded {len(r.text):,} bytes",
      flush=True
    )

    lines = r.text.splitlines()

    print(
      f"Returned {max(0, len(lines)-1):,} runs",
      flush=True
    )

    with open(args.output, "w") as f:
    f.write(r.text)

    print(
      f"Raw ENA results written to: {args.output}",
      flush=True
    )

    print("\nFirst 5 lines:", flush=True)

    for line in lines[:5]:
      print(line)


      if __name__ == "__main__":
        main()
