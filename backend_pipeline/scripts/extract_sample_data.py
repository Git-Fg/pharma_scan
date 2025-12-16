import os
import random

# Define paths
DATA_DIR = os.path.join(os.path.dirname(__file__), '../data')
OUTPUT_FILE = os.path.join(os.path.dirname(__file__), '../data/sampled_bdpm_data.txt')

def extract_random_lines():
    # Check if data directory exists
    if not os.path.exists(DATA_DIR):
        print(f"Error: Data directory not found at {DATA_DIR}")
        return

    # Open output file
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as outfile:
        # Iterate over all files in the data directory
        for filename in sorted(os.listdir(DATA_DIR)):
            if filename.endswith('.txt') and filename != 'sampled_bdpm_data.txt':
                filepath = os.path.join(DATA_DIR, filename)
                
                try:
                    # Attempt to read with CP1252 (Windows-1252) as per specs, fallback to utf-8 if needed
                    # The prompt mentions "bdpm" files which are usually CP1252.
                    try:
                        with open(filepath, 'r', encoding='utf-8') as infile:
                            lines = infile.readlines()
                    except UnicodeDecodeError:
                        # Fallback for other txt files that might be utf-8
                         with open(filepath, 'r', encoding='utf-8') as infile:
                            lines = infile.readlines()

                    # Select 50 random lines or all if less than 50
                    if len(lines) > 50:
                        sampled_lines = random.sample(lines, 50)
                    else:
                        sampled_lines = lines

                    # Write header
                    outfile.write(f"\n{'='*20} {filename} {'='*20}\n")
                    
                    # Write lines
                    for line in sampled_lines:
                        # Ensure line ends with newline
                        if not line.endswith('\n'):
                            line += '\n'
                        outfile.write(line)
                        
                    print(f"Processed {filename}: {len(sampled_lines)} lines extracted.")

                except Exception as e:
                    print(f"Error processing {filename}: {e}")

    print(f"\nExtraction complete. Output saved to {OUTPUT_FILE}")

if __name__ == "__main__":
    extract_random_lines()
