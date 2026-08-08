#!/bin/bash

# Get script directory and root
SCRIPT_DIR=$(cd $(dirname $0) && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

# Define source and original directories
MODIFIED_SRC="$ROOT_DIR/server/src"
ORIGINAL_SRC="$ROOT_DIR/../scrcpy/server/src"

echo "🔍 Finding all Java files in $MODIFIED_SRC..."
echo ""

# Counter for statistics
total_files=0
changed_files=0
new_files=0

# Find all Java files in modified source
# Use process substitution to avoid subshell issue with pipes
while read -r modified_file; do
    # Get relative path from server/src/
    relative_path="${modified_file#$MODIFIED_SRC/}"

    # Construct original file path
    original_file="$ORIGINAL_SRC/$relative_path"

    total_files=$((total_files + 1))

    # Check if original file exists
    if [[ ! -f "$original_file" ]]; then
        echo "⚠️  New file (no original): $relative_path"
        new_files=$((new_files + 1))
        continue
    fi

    # Generate diff
    echo "📝 Processing: $relative_path"

    # Save patch file next to the source file
    patch_file="${modified_file}.patch"

    # Generate unified diff
    diff -u "$original_file" "$modified_file" > "$patch_file"

    # Check if there are any differences
    if [[ ! -s "$patch_file" ]]; then
        echo "   ℹ️  No changes detected"
        rm "$patch_file"
    else
        echo "   ✅ Patch saved: ${patch_file#$ROOT_DIR/}"
        changed_files=$((changed_files + 1))
    fi
done < <(find "$MODIFIED_SRC" -type f -name "*.java" | sort)

echo ""
echo "🎉 Done! Patches saved next to source files with .patch extension"
echo "📊 Statistics:"
echo "   - Total Java files processed: $total_files"
echo "   - Files with changes: $changed_files"
echo "   - New files: $new_files"
