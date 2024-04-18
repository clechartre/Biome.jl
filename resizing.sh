#!/bin/bash

# Directory to start the search from
search_dir="/scratch/clechart/hackathon/data/train/altocumulus_copy_copy"

# Loop over all PNG files in subfolders
find "$search_dir" -type f -name '*.png' | while read img; do
  convert "$img" -resize "800x600>" "$img"
done
