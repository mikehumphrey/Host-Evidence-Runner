import pandas as pd
import argparse
import sys
import os

def analyze_chainsaw_results(csv_path, output_path):
    print(f"Loading Chainsaw results from {csv_path}...")
    try:
        df = pd.read_csv(csv_path)
    except Exception as e:
        print(f"Error loading CSV: {e}")
        return

    if df.empty:
        print("No data found in CSV.")
        return

    print(f"Loaded {len(df)} rows.")

    # Basic Analysis
    # 1. Top Detections
    # Chainsaw CSV columns usually include: group, kind, name, timestamp, etc.
    target_col = 'name'
    if target_col not in df.columns:
        # Try to find a likely column
        for col in ['Rule', 'rule', 'Detection', 'detection', 'detections']:
            if col in df.columns:
                target_col = col
                break
    
    if target_col in df.columns:
        top_rules = df[target_col].value_counts().head(10)
        rare_rules = df[target_col].value_counts()
        rare_rules = rare_rules[rare_rules < 5]
    else:
        print(f"Warning: Could not identify rule name column. Columns: {df.columns}")
        top_rules = pd.Series()
        rare_rules = pd.Series()

    summary = []
    summary.append("=== AI Analysis Summary ===")
    summary.append(f"Total Detections: {len(df)}")
    summary.append("\nTop 10 Detections:")
    for rule, count in top_rules.items():
        summary.append(f"  - {rule}: {count}")

    # 2. Rare Detections (Potential Anomalies)
    summary.append("\nRare Detections (Count < 5):")
    for rule, count in rare_rules.items():
        summary.append(f"  - {rule}: {count}")

    # Write output
    with open(output_path, 'w') as f:
        f.write('\n'.join(summary))
    
    print(f"Analysis written to {output_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Analyze Chainsaw results")
    parser.add_argument("input_csv", help="Path to chainsaw_hunt_results.csv")
    parser.add_argument("output_file", help="Path to output summary text file")
    
    args = parser.parse_args()
    
    if not os.path.exists(args.input_csv):
        print(f"Input file not found: {args.input_csv}")
        sys.exit(1)
        
    analyze_chainsaw_results(args.input_csv, args.output_file)
