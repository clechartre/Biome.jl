#!/bin/bash

# Base directory for the images
BASEDIR="/scratch/clechart/hackathon/data/train/cumulonimbus"  # Update this to your specific directory if necessary

# Directory to store the resized and converted images, parallel to BASEDIR
COPYDIR="/scratch/clechart/hackathon/data/train_copy"

# Create the _copy directory and a mirror of all subdirectories from BASEDIR
rsync -av --include '*/' --exclude '*' "$BASEDIR/" "$COPYDIR/"

# Find all image files and process them
find "$BASEDIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.bmp" \) -exec bash -c '
  file="$1"
  # Creating the target path by replacing the base directory with the copy directory
  target="${file/$BASEDIR/$COPYDIR}"
  # Extract the original extension (without the dot)
  ext="${file##*.}"
  # Convert and resize the image, rename to include the original extension before .png
  convert "$file" -resize 640x640\> "${target%.*}_${ext}.png"
' _ {} \;

echo "All images have been resized and converted in the '$COPYDIR' directory."
