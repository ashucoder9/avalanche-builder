#!/bin/bash

# Avalanche Developer Skill Installer for Claude Code
# This script installs the Avalanche development skill for Claude Code

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     Avalanche Developer Skill Installer for Claude Code   ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Determine the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Default installation directory
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"
SKILL_NAME="avalanche-dev"
INSTALL_DIR="${CLAUDE_SKILLS_DIR}/${SKILL_NAME}"

# Check if skill directory exists in script location
if [ -d "${SCRIPT_DIR}/skill" ]; then
    SOURCE_DIR="${SCRIPT_DIR}/skill"
else
    echo -e "${RED}Error: skill directory not found${NC}"
    echo "Please run this script from the repository root directory"
    exit 1
fi

# Create Claude skills directory if it doesn't exist
echo -e "${YELLOW}Creating skills directory...${NC}"
mkdir -p "${CLAUDE_SKILLS_DIR}"

# Check if skill already exists
if [ -d "${INSTALL_DIR}" ]; then
    echo -e "${YELLOW}Skill already exists. Updating...${NC}"
    rm -rf "${INSTALL_DIR}"
fi

# Copy skill files
echo -e "${YELLOW}Installing skill files...${NC}"
cp -r "${SOURCE_DIR}" "${INSTALL_DIR}"

# Verify installation
if [ -f "${INSTALL_DIR}/SKILL.md" ]; then
    echo -e "${GREEN}✓ Skill installed successfully!${NC}"
else
    echo -e "${RED}✗ Installation failed${NC}"
    exit 1
fi

# List installed files
echo ""
echo -e "${GREEN}Installed files:${NC}"
find "${INSTALL_DIR}" -type f -name "*.md" | while read file; do
    basename "$file"
done

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo -e "Skill installed to: ${YELLOW}${INSTALL_DIR}${NC}"
echo ""
echo -e "To use this skill, add it to your Claude Code configuration:"
echo ""
echo -e "${YELLOW}~/.claude/config.json:${NC}"
echo '{'
echo '  "skills": {'
echo '    "avalanche-dev": {'
echo "      \"path\": \"${INSTALL_DIR}\""
echo '    }'
echo '  }'
echo '}'
echo ""
echo -e "${GREEN}Or use the skill directly by referencing the SKILL.md file.${NC}"
echo ""

# Optional: Check for recommended tools
echo -e "${YELLOW}Checking for recommended tools...${NC}"

check_tool() {
    if command -v $1 &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $1 is installed"
        return 0
    else
        echo -e "  ${RED}✗${NC} $1 is not installed"
        return 1
    fi
}

echo ""
check_tool "node" || echo "    Install: https://nodejs.org"
check_tool "forge" || echo "    Install: curl -L https://foundry.paradigm.xyz | bash && foundryup"
check_tool "avalanche" || echo "    Install: curl -sSfL https://raw.githubusercontent.com/ava-labs/avalanche-cli/main/scripts/install.sh | sh -s"

echo ""
echo -e "${GREEN}Happy building on Avalanche! 🏔️${NC}"
