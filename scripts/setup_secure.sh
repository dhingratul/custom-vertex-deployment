#!/bin/bash

# This script helps set up the project with secure practices

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up secure Vertex AI deployment project...${NC}"

# Check if .env file exists and create from template if not
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Creating .env file from template...${NC}"
    cp .env.template .env
    echo -e "${GREEN}✅ Created .env file - please update it with your specific values${NC}"
else
    echo -e "${YELLOW}⚠️ .env file already exists. If needed, you can recreate it with: cp .env.template .env${NC}"
fi

# Check if key.json exists and inform user
if [ -f "key.json" ]; then
    echo -e "${RED}⚠️ WARNING: key.json file detected!${NC}"
    echo -e "${YELLOW}For security reasons, service account key files should not be stored in the repository.${NC}"
    echo -e "${YELLOW}Consider storing it securely and only placing it here temporarily during deployment.${NC}"
else
    echo -e "${YELLOW}No key.json file found. You will need to create a service account and download the key file.${NC}"
    echo -e "${YELLOW}See README.md for instructions on setting up service accounts securely.${NC}"
fi

# Check .gitignore for sensitive files
echo -e "${GREEN}Checking .gitignore configuration...${NC}"
MISSING_PATTERNS=()

check_gitignore() {
    if ! grep -q "$1" .gitignore; then
        MISSING_PATTERNS+=("$1")
    fi
}

check_gitignore ".env"
check_gitignore "key.json"
check_gitignore "*.pem"
check_gitignore "*.key"
check_gitignore "*credential*"
check_gitignore "*secret*"
check_gitignore "*token*"

if [ ${#MISSING_PATTERNS[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ .gitignore configured correctly for sensitive files${NC}"
else
    echo -e "${RED}⚠️ The following patterns are missing from .gitignore:${NC}"
    for pattern in "${MISSING_PATTERNS[@]}"; do
        echo -e "${YELLOW}  - $pattern${NC}"
    done
    echo -e "${YELLOW}Consider adding them to prevent accidentally committing sensitive information${NC}"
fi

# Verify scripts are executable
echo -e "${GREEN}Ensuring scripts are executable...${NC}"
chmod +x scripts/*.sh
echo -e "${GREEN}✅ Scripts are now executable${NC}"

# Check for already committed sensitive files
echo -e "${GREEN}Checking for sensitive files in Git history...${NC}"
SENSITIVE_FILES=$(git ls-files | grep -E '(key\.json|\.env|credential|secret|token|\.pem|\.key)')

if [ -n "$SENSITIVE_FILES" ]; then
    echo -e "${RED}⚠️ WARNING: The following sensitive files are tracked by Git:${NC}"
    echo -e "${YELLOW}$SENSITIVE_FILES${NC}"
    echo -e "${YELLOW}See README.md for instructions on cleaning up sensitive files from Git history.${NC}"
else
    echo -e "${GREEN}✅ No sensitive files detected in Git tracking${NC}"
fi

echo -e "${GREEN}Setup complete! Please review the above information and take any necessary actions.${NC}"
echo -e "${GREEN}See README.md for more information on security best practices.${NC}" 