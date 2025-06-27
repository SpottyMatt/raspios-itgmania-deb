#!/usr/bin/env python3
"""
Script to extract version, hash, and date from ITGMania binary
Usage: ./extract-version-from-binary.py <binary_path> [--major-minor-only|--hash-only|--date-only|--version-hash|--version-hash-date]
"""

import os
import re
import subprocess
import sys


def get_version_output(binary_path):
    """Execute binary --version and return the output."""
    try:
        result = subprocess.run(
            [binary_path, '--version'],
            capture_output=True,
            text=True,
            check=False  # Don't raise on non-zero exit
        )
        
        if result.returncode != 0:
            raise RuntimeError(f"Binary returned non-zero exit code: {result.returncode}")
            
        if not result.stdout.strip():
            raise RuntimeError("Binary produced no output")
            
        return result.stdout
        
    except FileNotFoundError:
        raise RuntimeError(f"Binary not found: {binary_path}")
    except PermissionError:
        raise RuntimeError(f"Binary not executable: {binary_path}")


def parse_version_info(version_output):
    """Parse version number, hash, and date from binary output."""
    lines = version_output.strip().split('\n')
    
    if len(lines) < 2:
        raise RuntimeError(f"Unexpected version output format: {version_output}")
    
    # Extract version from first line, handling formats like "ITGmania1.0.2-git-427484d100"
    version_pattern = r'ITGmania([0-9]+\.[0-9]+\.[0-9]+)'
    version_match = re.search(version_pattern, lines[0])
    if not version_match:
        raise RuntimeError(f"Could not parse version from output: {lines[0]}")
    version_num = version_match.group(1)
    
    # Extract hash from first line after "-git-"
    hash_pattern = r'-git-([a-f0-9]+)'
    hash_match = re.search(hash_pattern, lines[0])
    if not hash_match:
        raise RuntimeError(f"Could not parse hash from output: {lines[0]}")
    hash_value = hash_match.group(1)
    
    # Extract date from second line "Compiled 20250624 @ 00:32:41"
    date_pattern = r'Compiled ([0-9]{8})'
    date_match = re.search(date_pattern, lines[1])
    if not date_match:
        raise RuntimeError(f"Could not parse date from output: {lines[1]}")
    date_value = date_match.group(1)
    
    return version_num, hash_value, date_value


def main():
    # Handle arguments like bash script does
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <binary_path> [--major-minor-only|--hash-only|--date-only|--version-hash|--version-hash-date]", file=sys.stderr)
        sys.exit(1)
    
    binary_path = sys.argv[1]
    mode = sys.argv[2] if len(sys.argv) > 2 else 'full'
    
    # Validate binary exists and is executable
    if not os.path.exists(binary_path):
        print(f"Error: Binary not found: {binary_path}", file=sys.stderr)
        sys.exit(1)
        
    if not os.access(binary_path, os.X_OK):
        print(f"Error: Binary not executable: {binary_path}", file=sys.stderr)
        sys.exit(1)
    
    try:
        # Get version output from binary
        version_output = get_version_output(binary_path)
        
        # Parse the version information
        version_num, hash_value, date_value = parse_version_info(version_output)
        
        # Output based on requested mode
        if mode == '--major-minor-only':
            # Extract just major.minor (e.g., "1.0" from "1.0.2")
            major_minor = '.'.join(version_num.split('.')[:2])
            print(major_minor)
        elif mode == '--hash-only':
            print(hash_value)
        elif mode == '--date-only':
            print(date_value)
        elif mode == '--version-hash':
            # Return both space-separated: "1.0.2 427484d100"
            print(f"{version_num} {hash_value}")
        elif mode == '--version-hash-date':
            # Return all three space-separated: "1.0.2 427484d100 20250624"
            print(f"{version_num} {hash_value} {date_value}")
        else:
            # Default: just the version number
            print(version_num)
            
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
