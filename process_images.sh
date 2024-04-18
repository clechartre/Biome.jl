#!/bin/bash

module load imagemagick

# Base directory for all image directories
TRAIN_DIR="/scratch/clechart/hackathon/data/train/"

# Loop through each subdirectory in the train directory
for DIR in $TRAIN_DIR*/; do  # Ensuring only directories are processed
    if [ -d "$DIR" ]; then  # Check if it's a directory
        BASEDIR="$DIR"
        # Generate the copy directory name and ensure it ends with '_copy'
        COPYDIR="${DIR%/*}_copy/"

        # Create the COPYDIR directory and a mirror of all subdirectories from BASEDIR
        rsync -av --include '*/' --exclude '*' "$BASEDIR" "$COPYDIR"

        # Process each image file
        for file in $(find "$BASEDIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.bmp" \) ! -path "$COPYDIR*"); do
            # Calculate the target path by replacing BASEDIR in the file path with COPYDIR
            target="${file/$BASEDIR/$COPYDIR}"
            # Extract the original extension (without the dot)
            ext="${file##*.}"
            # Convert and resize the image, rename to include the original extension before .png
            target_file="${target%.*}_${ext}.png"
            mkdir -p "$(dirname "$target_file")" # Ensure the target directory exists
            convert "$file" -resize 640x640\> "$target_file"
        done

        echo "All images in '$DIR' have been resized, converted, and moved to '$COPYDIR'"
    fi
done

echo "Processing complete for all directories."
