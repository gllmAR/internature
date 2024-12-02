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

# Function to generate the subnavigation content recursively
generate_subnav_content() {
    local parent_dir="$1"
    local indent_level="$2"
    local content_lines=()

    # Remove trailing slash from parent_dir if any
    parent_dir="${parent_dir%/}"

    # Iterate over subdirectories and check for README.md
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

# Function to replace content between start and end tags only if it's not already there
replace_content_between_tags() {
    local readme_path="$1"
    local subnav_content="$2"

    # Check if start and end tags exist in the file
    if grep -q "<!-- start-replace-subnav -->" "$readme_path" && grep -q "<!-- end-replace-subnav -->" "$readme_path"; then
        echo "Processing $readme_path..."

        # Check if the subnav_content is already in the file
        if ! grep -qF "$subnav_content" "$readme_path"; then
            # Use sed to replace content between the tags
            sed -i '' "/<!-- start-replace-subnav -->/,/<!-- end-replace-subnav -->/{
                /<!-- start-replace-subnav -->/ { 
                    p 
                    r /dev/stdin
                    d
                }
                /<!-- end-replace-subnav -->/ p
            }" "$readme_path" <<< "$subnav_content"

            echo "Updated $readme_path with new subnav content."
        else
            echo "Skipping $readme_path, subnav content already exists."
        fi
    else
        echo "Skipping $readme_path, <!-- start-replace-subnav --> or <!-- end-replace-subnav --> not found."
    fi
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

    # Replace the content between the start and end tags
    replace_content_between_tags "$readme_path" "$subnav_content"
}

# Function to walk through directories and generate the subnav content
generate_subnav() {
    local dir_path="$1"

    # Remove trailing slash from dir_path if any
    dir_path="${dir_path%/}"

    # Check for README.md in the current directory
    if [[ -f "$dir_path/README.md" ]]; then
        # Generate sub-navigation in README.md
        generate_readme_in_subfolders "$dir_path"
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

# Start from the current directory
generate_subnav "$ROOT_DIR"
