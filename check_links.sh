#!/bin/bash
# Save as check_links.sh and run: bash check_links.sh

echo "Checking SUMMARY.md links..."
grep -oP '\(([^)]+\.md)\)' SUMMARY.md | tr -d '()' | while read -r file; do
  if [ ! -f "$file" ]; then
    echo "❌ MISSING: $file"
  fi
done
echo "✅ Link check complete"
