#!/bin/bash

# CrowdSec WordPress Log Cleaner
# Scans WordPress wp-content/uploads for CrowdSec plugin prod.log files and optionally deletes them.
# Author: Giorgos | License: MIT

logfile_list=$(mktemp)
find /var/lib/docker/volumes -type f -path "*/wp-content/uploads/crowdsec/logs/prod.log" -print0 > "$logfile_list"
count=$(tr -cd '\0' < "$logfile_list" | wc -c)

if [ "$count" -eq 0 ]; then
    echo "❌ No prod.log files found."
    rm -f "$logfile_list"
    exit 0
fi

echo "✅ Found $count prod.log files:"
echo "------------------------------------------"

total_size_bytes=0
declare -A file_list

i=1
while IFS= read -r -d '' file
do
    size_bytes=$(stat --format="%s" "$file")
    size_human=$(du -h "$file" | cut -f1)
    total_size_bytes=$((total_size_bytes + size_bytes))

    file_list["$i"]="$file:$size_bytes"
    echo "[$i] 📄 $file - $size_human"
    ((i++))
done < "$logfile_list"

total_size_human=$(numfmt --to=iec $total_size_bytes)

echo "------------------------------------------"
echo "Total: $count files, total size $total_size_human"
echo ""
echo "1) 🧹 Delete ALL"
echo "2) 🧹 Delete only files larger than X MB"
echo "3) ❌ Cancel (do nothing)"
read -p "👉 Select an option [1-3]: " action

case "$action" in
    1)
        echo "⚡ Deleting all files..."
        xargs -0 rm -f < "$logfile_list"
        echo "✅ All files have been deleted."
        ;;
    2)
        read -p "Enter size limit in MB (e.g., 100): " limit
        limit_bytes=$((limit * 1024 * 1024))

        deleted=0
        for index in "${!file_list[@]}"; do
            entry="${file_list[$index]}"
            filepath="${entry%%:*}"
            filesize="${entry##*:}"

            if [ "$filesize" -ge "$limit_bytes" ]; then
                rm -f "$filepath"
                echo "✅ Deleted $filepath"
                ((deleted++))
            fi
        done

        echo "Total deleted files: $deleted"
        ;;
    3)
        echo "⏭️ No files were deleted."
        ;;
    *)
        echo "❌ Invalid selection."
        ;;
esac

rm -f "$logfile_list"
