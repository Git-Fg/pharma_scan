#!/bin/bash

# Script to update theme usage from old to new naming
# This script will replace context.shadColors with context.colors and 
# context.shadTextTheme with context.typo in all dart files

echo "Updating theme usage across the project..."
echo "This will replace:"
echo "  - context.shadColors -> context.colors"
echo "  - context.shadTextTheme -> context.typo"
echo

# Find all .dart files in the lib directory and replace the patterns
find lib -name "*.dart" -type f -exec sed -i '' 's/\.shadColors/\.colors/g' {} \;
find lib -name "*.dart" -type f -exec sed -i '' 's/\.shadTextTheme/\.typo/g' {} \;

echo "All theme usage patterns updated!"
echo "Please run 'flutter analyze' to check for any remaining issues."