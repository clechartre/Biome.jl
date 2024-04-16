#!/bin/bash

# Base directory where train, test, and eval folders are located
base_dir="/scratch/clechart/hackathon/data"

# Loop through each folder in the train directory
for folder in "$base_dir/train/"*; do
    if [[ -d "$folder" ]]; then  # Check if it is a directory
        folder_name=$(basename "$folder")

        # Create corresponding test and eval folders if they do not exist
        mkdir -p "$base_dir/test/$folder_name"
        mkdir -p "$base_dir/eval/$folder_name"

        # Calculate total number of files
        total_files=$(find "$folder" -type f | wc -l)

        # Calculate 20% of total files for test
        num_test=$((total_files * 20 / 100))

        # Calculate 10% of total files for eval
        num_eval=$((total_files * 10 / 100))

        # Generate random files for test and move them
        find "$folder" -type f | shuf -n "$num_test" | while read -r file; do
            mv "$file" "$base_dir/test/$folder_name/"
        done

        # Update remaining files count and generate random files for eval
        find "$folder" -type f | shuf -n "$num_eval" | while read -r file; do
            mv "$file" "$base_dir/eval/$folder_name/"
        done
    fi
done
