#!/bin/bash

EXCLUDED_DIRS=(".git" "node_modules" "__pycache__" ".vscode")

# Get the current working directory (root of the project)
ROOT_DIR=$(pwd)

# Function to extract the title from README.md
get_title_from_readme() {
    local readme_path="$1"
    local title
    title=$(grep -m 1 "^# " "$readme_path" | sed 's/^# //')
    echo "$title"
}

# Function to check if README.md contains the generateSubNav comment
contains_generate_subnav_comment() {
    local readme_path="$1"
    grep -q '<!-- generateSubNav -->' "$readme_path"
}

# Function to generate the subnavigation content recursively
generate_subnav_content() {
    local parent_dir="$1"
    local indent_level="$2"
    local content_lines=()

    # Remove trailing slash from parent_dir if any
    parent_dir="${parent_dir%/}"

    # Iterate over subdirectories
    for subdir in "$parent_dir"/*/; do
        if [[ -d "$subdir" ]]; then
            # Remove trailing slash from subdir
            subdir="${subdir%/}"

            local base_dir
            base_dir=$(basename "$subdir")

            # Skip excluded directories
            if [[ " ${EXCLUDED_DIRS[*]} " =~ " ${base_dir} " ]]; then
                continue
            fi

            local subdir_readme="$subdir/README.md"
            local subdir_title

            # Only generate a link if the subdirectory contains a README.md
            if [[ -f "$subdir_readme" ]]; then
                subdir_title=$(get_title_from_readme "$subdir_readme")

                if [[ -z "$subdir_title" ]]; then
                    subdir_title="$base_dir"
                fi

                # Get relative path from ROOT_DIR
                local relative_path="${subdir#$ROOT_DIR/}"  # Remove ROOT_DIR and following slash
                relative_path="${relative_path#/}"          # Remove any leading slash
                relative_path="${relative_path%/}"          # Remove any trailing slash

                # Build the link
                local link
                if [[ -n "$relative_path" ]]; then
                    link="/${relative_path}/"
                else
                    link="/"
                fi

                # Build the line with proper indentation
                local indent=""
                for ((i=0; i<indent_level; i++)); do
                    indent+="    "  # 4 spaces
                done
                content_lines+=("${indent}* [${subdir_title}](${link})")

                # Recurse into subdirectories
                local sub_content
                sub_content=$(generate_subnav_content "$subdir" $((indent_level + 1)))
                if [[ -n "$sub_content" ]]; then
                    content_lines+=("$sub_content")
                fi
            fi
        fi
    done

    # Join the content lines with newlines
    local content=$(printf "%s\n" "${content_lines[@]}")
    echo "$content"
}

# Function to update README.md with the new subnav content
update_readme_with_subnav() {
    local readme_path="$1"
    local subnav_content="$2"
    local tmpfile=$(mktemp)
    local in_section=0
    local start_tag_found=0
    local end_tag_found=0

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == *'<!-- generateSubNav -->'* ]]; then
            echo "$line" >> "$tmpfile"
            in_section=1
            start_tag_found=1
            # Write the subnav content immediately after the start tag
            echo "$subnav_content" >> "$tmpfile"
        elif [[ "$line" == *'<!-- generateSubNavEnd -->'* ]]; then
            echo "$line" >> "$tmpfile"
            in_section=0
            end_tag_found=1
        elif [[ $in_section -eq 0 ]]; then
            echo "$line" >> "$tmpfile"
        fi
        # If in_section is 1 (between tags), skip the line
    done < "$readme_path"

    if [[ $start_tag_found -eq 1 && $end_tag_found -eq 0 ]]; then
        # Add the end tag if it was missing
        echo "<!-- generateSubNavEnd -->" >> "$tmpfile"
    fi

    if [[ $start_tag_found -eq 0 ]]; then
        # Start tag not found; append the content at the end of tmpfile
        {
            echo -e "\n<!-- generateSubNav -->"
            echo "$subnav_content"
            echo "<!-- generateSubNavEnd -->"
        } >> "$tmpfile"
    fi

    # Replace the original file with the updated content
    mv "$tmpfile" "$readme_path"
}

# Function to generate README.md in subfolders
generate_readme_in_subfolders() {
    local parent_dir="$1"
    local readme_path="$parent_dir/README.md"
    
    # Extract title from the current README.md
    local title
    title=$(get_title_from_readme "$readme_path")
    if [[ -z "$title" ]]; then
        title=$(basename "$parent_dir")
    fi

    # Generate the subnav content
    local subnav_content
    subnav_content=$(generate_subnav_content "$parent_dir" 0)

    # Update the README.md with the new subnav content
    update_readme_with_subnav "$readme_path" "$subnav_content"
}

# Function to walk through directories and generate the subnav content
generate_subnav() {
    local dir_path="$1"

    # Remove trailing slash from dir_path if any
    dir_path="${dir_path%/}"

    # Check for README.md in the current directory
    if [[ -f "$dir_path/README.md" ]]; then
        # Check if README.md contains the generateSubNav comment
        if contains_generate_subnav_comment "$dir_path/README.md"; then
            generate_readme_in_subfolders "$dir_path"
        fi
    else
        echo "Skipped directory (no README.md): $dir_path"
    fi

    # Recurse into subdirectories, avoiding excluded directories
    for subdir in "$dir_path"/*/; do
        # Ensure subdir is a directory
        if [[ -d "$subdir" ]]; then
            # Remove trailing slash from subdir
            subdir="${subdir%/}"

            local base_dir
            base_dir=$(basename "$subdir")
            if [[ ! " ${EXCLUDED_DIRS[*]} " =~ " ${base_dir} " ]]; then
                generate_subnav "$subdir"
            fi
        fi
    done
}

# Start from the root directory
generate_subnav "$ROOT_DIR"
for dir in */; do
    if [[ -d "$dir" ]]; then
        generate_subnav "$dir"
    fi
done
