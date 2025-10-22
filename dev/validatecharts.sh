#!/bin/bash

# This script performs the following tasks:
# 1. Renders the templates in a Helm chart and outputs the resulting Kubernetes YAML manifest.
#    The generated YAML file is created using the values provided in the corresponding chart's values.yaml file.
# 2. Validates the generated YAML file to ensure it is a valid YAML file.
# 3. Searches the generated YAML file for proxy endpoints where the config is empty.
# 4. Generates a text file for each sub-chart of tp-cp-core where:
#    - The proxy config was found to be empty.
#    - The FQDN was not empty or nil.
# 5. The generated text file contains:
#    - The exact endpoint path for which the config was empty.
#    - The FQDN of the endpoint.
# 6. Deletes the zip files created during the process.

# Usage: ./validatechart.sh

set -euo pipefail

# Function to install missing tools
install_tool() {
  local tool=$1
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v apt-get &> /dev/null; then
      sudo apt-get update
      sudo apt-get install -y "$tool"
    elif command -v yum &> /dev/null; then
      sudo yum install -y "$tool"
    else
      echo "Error: Package manager not found. Please install $tool manually."
      exit 1
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v brew &> /dev/null; then
      brew install "$tool"
    else
      echo "Error: Homebrew not found. Please install Homebrew and try again."
      exit 1
    fi
  elif [[ "$OSTYPE" == "msys" ]]; then
    if command -v scoop &> /dev/null; then
      scoop install "$tool"
    else
      echo "Error: Scoop not found. Please install Scoop and try again."
      exit 1
    fi
  else
    echo "Error: Unsupported OS. Please install $tool manually."
    exit 1
  fi
}

# Check if required commands are available and install if missing
for cmd in zip helm yq; do
  if ! command -v $cmd &> /dev/null; then
    echo "$cmd is not installed. Installing..."
    install_tool $cmd
  fi
done

# Define the directory to search
parent_chart_dir="../charts/tp-cp-core/charts/"
validated_child_chart="validated-chart"

# Function to print the corresponding path value and FQDN
print_path_and_fqdn() {
  local file=$1
  local output_file=$2
  local path_pattern=$3
  yq eval "$path_pattern" "$file" | sort | uniq | while read -r path; do
    fqdn=$(yq eval ".spec.endpoints[] | select(.path == \"$path\") | .proxies[] | select(.config == \"empty\") | .fqdn" "$file")
    if [ -z "$fqdn" ]; then
      fqdn="N/A"
    fi
    echo "$path (fqdn: $fqdn)" >> "$output_file"
  done
}

# Initialize an array to store the generated output files and their associated YAML files
generated_files=()

# Iterate through parent chart folder and zip child parent's template folder
for child_chart in "$parent_chart_dir"/*; do
  if [ -d "$child_chart/templates" ]; then
    template_dir="$child_chart/templates"
    echo "Zipping $template_dir"
    zip -r "${template_dir}.zip" "$template_dir"

    # Extract the child chart name
    child_chart_name=$(basename "$child_chart")

    # Run helm template on the zipped folder and save the output with concatenated name
    yaml_file="$template_dir/${validated_child_chart}_${child_chart_name}.yaml"
    helm template "$child_chart" --values "$child_chart/values.yaml" > "$yaml_file"

    # Check if the file is a valid YAML file
    if ! yq eval '.' "$yaml_file"; then
      echo "Error: bad file '$yaml_file': not a valid YAML file"
      continue
    fi

    # Define the output file for the current child chart
    output_file="${template_dir}/${validated_child_chart}_${child_chart_name}_output.txt"

    # Delete any existing output file
    rm -f "$output_file"

    # Use yq to find occurrences of 'config: empty'
    empty_configs=$(yq eval '.spec.endpoints[].proxies[] | select(.config == "empty")' "$yaml_file")
    if [ -n "$empty_configs" ]; then
      # Print the path and FQDN for 'config: empty'
      print_path_and_fqdn "$yaml_file" "$output_file" '.spec.endpoints[].path'
      # Add the output file and associated YAML file to the list of generated files
      generated_files+=("$output_file\n  (associated YAML: $yaml_file)")
    else
      echo "No 'config: empty' found in $yaml_file"
    fi
  fi

  # Delete the zip files
  rm -f "${template_dir}.zip"
done

# Output the summary of generated files
echo -e "\nGenerated output files:"
for file in "${generated_files[@]}"; do
  echo -e "\n$file"
done
