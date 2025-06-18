#!/bin/bash
set -e

# Get the absolute path of the script
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# Configuration
REMOTE_HOST="dance@famipi"
REMOTE_BUILD_DIR="raspios-itgmania-deb"
DEFAULT_TARGET="all"
BUILD_SUBDIR="raspios-itgmania-deb"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Parse arguments
FRESH_BUILD=false
TARGET=""
RELEASE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --fresh)
            FRESH_BUILD=true
            shift
            ;;
        --release)
            RELEASE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--fresh] [--release] [target]"
            echo "  --fresh    Use temporary directory for completely fresh build"
            echo "  --release  Build a release package (without date stamp)"
            echo "  target     Make target to build (default: $DEFAULT_TARGET)"
            echo ""
            echo "Default behavior: Reuse existing build directory and update git ref"
            echo "Fresh build: Clone to /tmp directory for completely clean build"
            exit 0
            ;;
        *)
            if [[ -z "$TARGET" ]]; then
                TARGET="$1"
            else
                log_error "Unknown argument: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

TARGET=${TARGET:-$DEFAULT_TARGET}

if [[ "$FRESH_BUILD" == "true" ]]; then
    TIMESTAMP_FOR_DIR=$(date +"%Y%m%d-%H%M%S")
    REMOTE_BUILD_DIR="/tmp/raspios-itgmania-deb-${TIMESTAMP_FOR_DIR}"
    log_info "Using fresh build mode - temporary directory: $REMOTE_BUILD_DIR"
else
    log_info "Using persistent build mode - reusing directory: ~/$REMOTE_BUILD_DIR"
fi

log_info "Starting remote build for target: $TARGET"

# Determine if we're in the parent directory or the build directory
if [[ "$(basename "$PWD")" == "$BUILD_SUBDIR" ]]; then
    # We're in the build directory
    log_info "Running from build directory: $PWD"
    # Set the repository directory to the current directory (build directory)
    REPO_DIR="$PWD"
else
    # We're in the parent directory
    log_info "Running from parent directory: $PWD"
    # Repository is in the build subdirectory
    REPO_DIR="$PWD/$BUILD_SUBDIR"
    # Check if build directory exists
    if [[ ! -d "$REPO_DIR" ]]; then
        log_error "Build directory $REPO_DIR not found!"
        exit 1
    fi
fi

# Change to repository root for git operations
cd "$REPO_DIR"

# Step 1: Pre-flight checks
log_info "Checking for uncommitted/unpushed changes..."

# Check for uncommitted changes
if ! git --no-pager diff-index --quiet HEAD --; then
    log_error "You have uncommitted changes. Please commit them first."
    exit 1
fi

# Check for unpushed commits
LOCAL_COMMIT=$(git --no-pager rev-parse HEAD)
BRANCH=$(git --no-pager rev-parse --abbrev-ref HEAD)

# Try to fetch to get latest remote state (but don't fail if offline)
git --no-pager fetch origin 2>/dev/null || log_warn "Could not fetch from origin (offline?)"

# Check if local is ahead of remote
if git --no-pager rev-list --count HEAD ^origin/$BRANCH 2>/dev/null | grep -q '^[1-9]'; then
    log_error "You have unpushed commits on branch $BRANCH. Please push them first."
    exit 1
fi

SHORT_SHA=$(git --no-pager rev-parse --short HEAD)
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_NAME="${TIMESTAMP}-${SHORT_SHA}-${TARGET}.log"

log_info "Branch: $BRANCH"
log_info "Commit: $LOCAL_COMMIT ($SHORT_SHA)"
log_info "Log file: $LOG_NAME"

# Step 2: Remote setup and build
log_info "Connecting to $REMOTE_HOST..."

# Get the remote URL and convert SSH to HTTPS for remote machine
ORIGIN_URL=$(git --no-pager config --get remote.origin.url)
if [[ "$ORIGIN_URL" =~ ^git@(.+):(.+)\.git$ ]]; then
    # Convert SSH format to HTTPS
    REMOTE_REPO_URL="https://github.com/${BASH_REMATCH[2]}.git"
else
    # Use as-is (already HTTPS or other format)
    REMOTE_REPO_URL="$ORIGIN_URL"
fi

log_info "Remote will clone from: $REMOTE_REPO_URL"

# Create the remote build script
REMOTE_SCRIPT=$(cat <<EOF
#!/bin/bash
set -e

# Colors for remote output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "\${BLUE}[REMOTE]${NC} Starting remote build on \$(hostname)"
echo -e "\${BLUE}[REMOTE]${NC} Build mode: $(if [[ "$FRESH_BUILD" == "true" ]]; then echo "FRESH"; else echo "PERSISTENT"; fi)"
echo -e "\${BLUE}[REMOTE]${NC} Target directory: $REMOTE_BUILD_DIR"

if [[ "$FRESH_BUILD" == "true" ]]; then
    # Fresh build mode - clean clone
    if [ -d "$REMOTE_BUILD_DIR" ]; then
        echo -e "\${BLUE}[REMOTE]${NC} Removing existing temporary directory"
        rm -rf "$REMOTE_BUILD_DIR"
    fi
    
    echo -e "\${BLUE}[REMOTE]${NC} Cloning repository recursively (this may take a while)..."
    git clone --recursive $REMOTE_REPO_URL "$REMOTE_BUILD_DIR"
    
    cd "$REMOTE_BUILD_DIR"
    echo -e "\${BLUE}[REMOTE]${NC} Checking out commit $LOCAL_COMMIT"
    git checkout $LOCAL_COMMIT
    git submodule update --recursive
else
    # Persistent build mode - reuse existing directory
    if [ -d "$REMOTE_BUILD_DIR" ]; then
        echo -e "\${BLUE}[REMOTE]${NC} Using existing build directory"
        cd "$REMOTE_BUILD_DIR"
        
        # Clean any uncommitted changes
        echo -e "\${BLUE}[REMOTE]${NC} Cleaning working directory..."
        git reset --hard HEAD
        git clean -fd
        
        # Fetch latest changes
        echo -e "\${BLUE}[REMOTE]${NC} Fetching updates..."
        git fetch origin
        
        # Checkout the specific commit
        echo -e "\${BLUE}[REMOTE]${NC} Checking out commit $LOCAL_COMMIT"
        git checkout $LOCAL_COMMIT
        
        # Update submodules
        echo -e "\${BLUE}[REMOTE]${NC} Updating submodules..."
        git submodule update --init --recursive
    else
        echo -e "\${BLUE}[REMOTE]${NC} Build directory doesn't exist, creating with recursive clone..."
        git clone --recursive $REMOTE_REPO_URL "$REMOTE_BUILD_DIR"
        
        cd "$REMOTE_BUILD_DIR"
        echo -e "\${BLUE}[REMOTE]${NC} Checking out commit $LOCAL_COMMIT"
        git checkout $LOCAL_COMMIT
    fi
fi

# Create logs directory if it doesn't exist
mkdir -p logs

# Run the build
echo -e "\${BLUE}[REMOTE]${NC} Starting build target: $TARGET"
if [[ "$RELEASE" == "true" ]]; then
    make $TARGET RELEASE=true 2>&1 | tee "logs/$LOG_NAME"
else
    make $TARGET 2>&1 | tee "logs/$LOG_NAME"
fi

echo -e "\${GREEN}[REMOTE]${NC} Build completed successfully"
EOF
)

# Execute the remote build
ssh "$REMOTE_HOST" "$REMOTE_SCRIPT"

# Step 3: Retrieve the log file
log_info "Retrieving build log..."
mkdir -p "$REPO_DIR/logs"
scp "$REMOTE_HOST:$REMOTE_BUILD_DIR/logs/$LOG_NAME" "$REPO_DIR/logs/$LOG_NAME"

# Step 4: Retrieve the built packages
log_info "Retrieving built packages..."
mkdir -p "$REPO_DIR/target"
scp "$REMOTE_HOST:$REMOTE_BUILD_DIR/target/*.deb" "$REPO_DIR/target/" || log_warn "No packages were built or an error occurred during transfer"

# Step 5: Cleanup remote directory (only for fresh builds)
if [[ "$FRESH_BUILD" == "true" ]]; then
    log_info "Cleaning up temporary remote build directory..."
    ssh "$REMOTE_HOST" "rm -rf $REMOTE_BUILD_DIR"
else
    log_info "Keeping persistent build directory for future builds"
fi

log_success "Build completed! Log available at: $REPO_DIR/logs/$LOG_NAME"
log_info "To view the log: less $REPO_DIR/logs/$LOG_NAME"
if [ -d "$REPO_DIR/target" ] && [ "$(ls -A "$REPO_DIR/target" 2>/dev/null)" ]; then
    log_success "Built packages available in: $REPO_DIR/target/"
fi 