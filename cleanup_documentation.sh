#!/bin/bash
# Documentation Cleanup Script
# Consolidates redundant documentation files into Archive/
# Date: 2026-03-24

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Orascan Documentation Cleanup${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Change to project root
cd "$(dirname "$0")"
PROJECT_ROOT=$(pwd)
DOC_HUB="$PROJECT_ROOT/Orascan_Documentation_Hub"
ARCHIVE_DIR="$DOC_HUB/Archive"

echo -e "${YELLOW}Project root:${NC} $PROJECT_ROOT"
echo -e "${YELLOW}Documentation hub:${NC} $DOC_HUB"
echo ""

# Step 1: Create Archive directory
echo -e "${BLUE}Step 1: Creating Archive directory...${NC}"
if [ ! -d "$ARCHIVE_DIR" ]; then
    mkdir -p "$ARCHIVE_DIR"
    echo -e "${GREEN}✓${NC} Created $ARCHIVE_DIR"
else
    echo -e "${YELLOW}⚠${NC} Archive directory already exists"
fi
echo ""

# Step 2: Move superseded documents to Archive
echo -e "${BLUE}Step 2: Moving superseded documents to Archive...${NC}"

FILES_TO_ARCHIVE=(
    "CODE_REVIEW.md"
    "IMPLEMENTATION_COMPLETE.md"
    "SPRINT_0_SUMMARY.md"
    "SPRINT_1_SUMMARY.md"
    "architectural_deep_dive.md"
    "codebase_analysis.md"
)

cd "$DOC_HUB"

for file in "${FILES_TO_ARCHIVE[@]}"; do
    if [ -f "$file" ]; then
        mv "$file" Archive/
        echo -e "${GREEN}✓${NC} Moved $file to Archive/"
    else
        echo -e "${YELLOW}⚠${NC} $file not found (may already be archived)"
    fi
done
echo ""

# Step 3: Move backend FIXES_IMPLEMENTED.md to Archive
echo -e "${BLUE}Step 3: Moving backend documentation to Archive...${NC}"
BACKEND_FIXES="$PROJECT_ROOT/OraScan_backend/FIXES_IMPLEMENTED.md"
if [ -f "$BACKEND_FIXES" ]; then
    mv "$BACKEND_FIXES" "$ARCHIVE_DIR/"
    echo -e "${GREEN}✓${NC} Moved FIXES_IMPLEMENTED.md to Archive/"
else
    echo -e "${YELLOW}⚠${NC} Backend FIXES_IMPLEMENTED.md not found"
fi
echo ""

# Step 4: Remove redundant framework doc
echo -e "${BLUE}Step 4: Removing redundant files...${NC}"
if [ -f "$DOC_HUB/implement.md" ]; then
    rm "$DOC_HUB/implement.md"
    echo -e "${GREEN}✓${NC} Removed implement.md (redundant with SELF_MAINTAINING_DOCS_FRAMEWORK.md)"
else
    echo -e "${YELLOW}⚠${NC} implement.md not found"
fi
echo ""

# Step 5: Create Archive README
echo -e "${BLUE}Step 5: Creating Archive README...${NC}"
cat > "$ARCHIVE_DIR/README.md" << 'EOF'
# Archive - Historical Documentation

This directory contains superseded documentation for historical reference.

**Current Documentation:** See parent directory

---

## Archived Documents

### Code Reviews
- **CODE_REVIEW.md** (Mar 14, 2026)
  - Superseded by: `COMPREHENSIVE_CODE_REVIEW_2026-03-24.md`
  - Content: Original comprehensive code review with 67 findings

### Implementation Summaries
- **IMPLEMENTATION_COMPLETE.md** (Mar 18, 2026)
  - Superseded by: `IMPLEMENTATION_SUMMARY_2026-03-24.md` + `MASTER_ISSUES.md`
  - Content: Sprint 0-2 implementation summary

- **FIXES_IMPLEMENTED.md** (Backend, Mar 18, 2026)
  - Superseded by: `MASTER_ISSUES.md` + `IMPLEMENTATION_SUMMARY_2026-03-24.md`
  - Content: Detailed fix list from Sprint 0-2

### Sprint Summaries
- **SPRINT_0_SUMMARY.md** (Mar 18, 2026)
  - Superseded by: `MASTER_ISSUES.md`
  - Content: Security emergency sprint (P0 critical fixes)

- **SPRINT_1_SUMMARY.md** (Mar 18, 2026)
  - Superseded by: `MASTER_ISSUES.md`
  - Content: Architecture & deduplication sprint (P1 high priority)

### Architecture Analysis
- **architectural_deep_dive.md** (Feb 19, 2026)
  - Superseded by: `COMPREHENSIVE_CODE_REVIEW_2026-03-24.md` (Architecture section)
  - Content: Early architecture analysis

- **codebase_analysis.md** (Feb 19, 2026)
  - Superseded by: `COMPREHENSIVE_CODE_REVIEW_2026-03-24.md`
  - Content: Initial codebase structure overview

---

## Why These Files Were Archived

These documents were superseded by more comprehensive, up-to-date documentation:

1. **MASTER_ISSUES.md** - Consolidated all issue tracking from sprint summaries
2. **COMPREHENSIVE_CODE_REVIEW_2026-03-24.md** - Latest complete review
3. **IMPLEMENTATION_SUMMARY_2026-03-24.md** - Latest implementation details

The archived files are retained for:
- Historical reference
- Audit trail
- Understanding evolution of the project
- Tracing decision history

---

**Archive Created:** 2026-03-24
**Maintained By:** Development Team
EOF

echo -e "${GREEN}✓${NC} Created Archive/README.md"
echo ""

# Step 6: Summary
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Cleanup Summary${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

echo -e "${GREEN}Active Documentation:${NC}"
cd "$DOC_HUB"
ls -1 *.md | grep -v "^Archive$"
echo ""

echo -e "${YELLOW}Archived Documents:${NC}"
ls -1 Archive/*.md
echo ""

# Count files
ACTIVE_COUNT=$(ls -1 *.md 2>/dev/null | wc -l | tr -d ' ')
ARCHIVED_COUNT=$(ls -1 Archive/*.md 2>/dev/null | wc -l | tr -d ' ')

echo -e "${GREEN}✓${NC} Active documentation files: $ACTIVE_COUNT"
echo -e "${YELLOW}✓${NC} Archived documentation files: $ARCHIVED_COUNT"
echo ""

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Documentation Cleanup Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Next steps:"
echo "1. Review active documentation in: $DOC_HUB"
echo "2. Check MASTER_ISSUES.md for issue tracking"
echo "3. Review GIT_MERGE_REPORT.md for merge safety"
echo ""
