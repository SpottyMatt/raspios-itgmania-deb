#!/usr/bin/env python3
"""
Script to extract version, hash, and date from ITGMania binary
Usage: ./extract-version-from-binary.py <binary_path> [--major-minor-only|--hash-only|--date-only|--version-hash|--version-hash-date]
"""

import argparse
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
    parser = argparse.ArgumentParser(
        description="Extract version, hash, and date from ITGMania binary",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s /usr/local/itgmania/itgmania
  %(prog)s /usr/local/itgmania/itgmania --major-minor-only
  %(prog)s /usr/local/itgmania/itgmania --version-hash-date
        """
    )
    
    parser.add_argument('binary_path', help='Path to the ITGMania binary')
    parser.add_argument('mode', nargs='?', default='full',
                       help='Output mode: --major-minor-only, --hash-only, --date-only, --version-hash, --version-hash-date, or full (default)')
    
    args = parser.parse_args()
    
    # Validate binary exists and is executable
    if not os.path.exists(args.binary_path):
        print(f"Error: Binary not found: {args.binary_path}", file=sys.stderr)
        sys.exit(1)
        
    if not os.access(args.binary_path, os.X_OK):
        print(f"Error: Binary not executable: {args.binary_path}", file=sys.stderr)
        sys.exit(1)
    
    try:
        # Get version output from binary
        version_output = get_version_output(args.binary_path)
        
        # Parse the version information
        version_num, hash_value, date_value = parse_version_info(version_output)
        
        # Output based on requested mode
        if args.mode == '--major-minor-only':
            # Extract just major.minor (e.g., "1.0" from "1.0.2")
            major_minor = '.'.join(version_num.split('.')[:2])
            print(major_minor)
        elif args.mode == '--hash-only':
            print(hash_value)
        elif args.mode == '--date-only':
            print(date_value)
        elif args.mode == '--version-hash':
            # Return both space-separated: "1.0.2 427484d100"
            print(f"{version_num} {hash_value}")
        elif args.mode == '--version-hash-date':
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
