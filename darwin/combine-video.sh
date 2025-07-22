#!/bin/sh

OUTPUT_DIR="grouped_videos"
TEMP_DIR="temp_concat_lists"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$TEMP_DIR"

OS_TYPE=$(uname)
case "$OS_TYPE" in
    Darwin)
        echo "macOS detected - using VideoToolbox hardware acceleration"
        VIDEO_CODEC="hevc_videotoolbox"
        CODEC_OPTIONS='-q:v 65 -tag:v hvc1'
        ;;
    *)
        echo "Using software H.265 encoding"
        VIDEO_CODEC="libx265"
        CODEC_OPTIONS='-crf 23 -preset medium'
        ;;
esac

echo "Listing and ranking video files..."
printf '%s\n' *.mp4 2>/dev/null | sort -V > all_files.txt

TOTAL_FILES=$(wc -l < all_files.txt)
echo "Found $TOTAL_FILES video files"

if [ "$TOTAL_FILES" -eq 0 ]; then
    echo "No mp4 files found in current directory"
    exit 1
fi

if [ "$TOTAL_FILES" -lt 60 ]; then
    echo "Warning: Only $TOTAL_FILES files found, less than 60"
    FILES_TO_PROCESS=$TOTAL_FILES
else
    FILES_TO_PROCESS=60
fi

head -n "$FILES_TO_PROCESS" all_files.txt > ranked_files.txt

GROUP_SIZE=20
GROUP_COUNT=$(((FILES_TO_PROCESS + GROUP_SIZE - 1) / GROUP_SIZE))

echo "Creating $GROUP_COUNT groups of up to $GROUP_SIZE files each"
echo "Total files to process: $FILES_TO_PROCESS"

group=1
while [ "$group" -le "$GROUP_COUNT" ]; do
    START_LINE=$(((group - 1) * GROUP_SIZE + 1))
    END_LINE=$((group * GROUP_SIZE))

    if [ "$END_LINE" -gt "$FILES_TO_PROCESS" ]; then
        END_LINE=$FILES_TO_PROCESS
    fi

    GROUP_TEMP_FILE="$TEMP_DIR/group_${group}_files.txt"
    sed -n "${START_LINE},${END_LINE}p" ranked_files.txt > "$GROUP_TEMP_FILE"

    GROUP_FILE_COUNT=$(wc -l < "$GROUP_TEMP_FILE")

    if [ "$GROUP_FILE_COUNT" -eq 0 ]; then
        echo "No more files to process. Stopping."
        rm -f "$GROUP_TEMP_FILE"
        break
    fi

    echo ""
    echo "=== GROUP $group ==="
    echo "Files $START_LINE to $END_LINE ($GROUP_FILE_COUNT files):"
    echo ""

    first_ten=""
    second_ten=""
    file_num=0

    while IFS= read -r file; do
        file_num=$((file_num + 1))
        if [ "$file_num" -le 10 ]; then
            first_ten="$first_ten $file"
        else
            second_ten="$second_ten $file"
        fi
    done < "$GROUP_TEMP_FILE"

    echo "[1] $first_ten"
    echo "[2] $second_ten"

    echo ""
    printf "Do you want to process Group %s? (y/n): " "$group"
    read -r REPLY

    case "$REPLY" in
        [Yy]*)
            CONCAT_FILE="$TEMP_DIR/group_${group}_list.txt"
            OUTPUT_FILE="$OUTPUT_DIR/combined_group_${group}.mp4"

            echo "Processing group $group..."

            : > "$CONCAT_FILE"

            while IFS= read -r file; do
                if [ -f "$file" ]; then
                    echo "file '../$file'" >> "$CONCAT_FILE"
                fi
            done < "$GROUP_TEMP_FILE"

            if [ -s "$CONCAT_FILE" ]; then
                echo "Combining group $group into $OUTPUT_FILE..."
                if ffmpeg -f concat -safe 0 -i "$CONCAT_FILE" \
                    -c:v "$VIDEO_CODEC" \
                    $CODEC_OPTIONS \
                    -c:a aac \
                    -b:a 128k \
                    -y "$OUTPUT_FILE"; then
                    echo "Successfully created $OUTPUT_FILE"
                else
                    echo "Error creating $OUTPUT_FILE"
                fi
            else
                echo "No valid files for group $group"
            fi
            ;;
        *)
            echo "Skipping Group $group"
            ;;
    esac

    rm -f "$GROUP_TEMP_FILE"
    group=$((group + 1))
done

rm -rf "$TEMP_DIR"
rm -f all_files.txt ranked_files.txt

echo "Process completed. Output files are in the '$OUTPUT_DIR' directory."
