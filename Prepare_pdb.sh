#!/bin/bash

# Function to display help
function show_help {
    echo "Usage: $0 -i INPUT_PDB -p PH_VALUE -f FORCE_FIELD -o OUTPUT_PQR"
    echo ""
    echo "Arguments:"
    echo "  -i  Input PDB file (required)"
    echo "  -p  pH value for protonation state (default: 7.0)"
    echo "  -f  Force field to use (default: amber)"
    echo "  -o  Output PQR file (default: prepared.pqr)"
    echo "  -h  Display this help message"
    echo ""
    echo "Description:"
    echo "  This script prepares a PDB file for docking by:"
    echo "    - Filling missing residues and atoms using PDBFixer."
    echo "    - Assigning protonation states using pdb2pqr based on the specified pH."
    echo "    - Generating a PQR file with charges and radii."
    echo "    - Optionally converting the PQR file back to PDB format."
    echo ""
    echo "Dependencies:"
    echo "  - PDBFixer (install via pip)."
    echo "  - pdb2pqr (install via conda or your package manager)."
    echo "  - Open Babel (install via conda or your package manager)."
    echo ""
}

# Default values
PH=7.0
FORCE_FIELD="AMBER"
OUTPUT_PQR="prepared.pqr"
ffout="AMBER"

# Parse arguments
while getopts "i:p:f:o:h" opt; do
    case ${opt} in
        i) INPUT_PDB="${OPTARG}" ;;
        p) PH="${OPTARG}" ;;
        f) FORCE_FIELD="${OPTARG}" ;;
        o) OUTPUT_PQR="${OPTARG}" ;;
        h) show_help
           exit 0 ;;
        *) echo "Invalid option: -$OPTARG" >&2
           show_help
           exit 1 ;;
    esac
done

# Check if input file is provided
if [ -z "$INPUT_PDB" ]; then
    echo "Error: Input PDB file is required."
    show_help
    exit 1
fi

# Check if PDBFixer is installed
if ! command -v python3 &> /dev/null || ! python3 -c "import pdbfixer" &> /dev/null; then
    echo "Error: PDBFixer is not installed. Install it using pip: pip install pdbfixer"
    exit 1
fi

# Check if pdb2pqr is installed
if ! command -v pdb2pqr &> /dev/null; then
    echo "Error: pdb2pqr is not installed. Install it via conda or your package manager."
    exit 1
fi

# Check if Open Babel is installed
if ! command -v obabel &> /dev/null; then
    echo "Error: Open Babel is not installed. Install it via conda or your package manager."
    exit 1
fi

# Step 1: Fix Missing Residues and Atoms Using PDBFixer
echo "Step 1: Fixing missing residues and atoms with PDBFixer..."
cat > fix_structure.py <<EOL
from pdbfixer import PDBFixer
from openmm.app import PDBFile

# Load the input PDB file
fixer = PDBFixer(filename="${INPUT_PDB}")

# Find and fix missing residues and atoms
fixer.findMissingResidues()
fixer.findMissingAtoms()
fixer.addMissingAtoms()

# Add hydrogens for a neutral baseline (default pH)
#fixer.addMissingHydrogens()

# Save the fixed PDB file
with open("fixed.pdb", "w") as f:
    PDBFile.writeFile(fixer.topology, fixer.positions, f)
print("PDBFixer: Missing residues and atoms fixed. Saved as fixed.pdb.")
EOL

# Run the PDBFixer script
python3 fix_structure.py

if [ $? -ne 0 ]; then
    echo "Error: PDBFixer failed to process the file. Check the input structure."
    exit 1
fi

echo "Missing residues and atoms filled successfully. Output saved as fixed.pdb."

# Step 2: Assign Protonation States Using pdb2pqr
echo "Step 2: Assigning protonation states with pdb2pqr..."
pdb2pqr --ff="$FORCE_FIELD"  --clean  --with-ph="$PH"  fixed.pdb "$OUTPUT_PQR" 

if [ $? -eq 0 ]; then
    echo "PDB preparation successful. Output saved to $OUTPUT_PQR"
else
    echo "Error during PDB preparation. Check pdb2pqr logs for details."
    exit 1
fi

# Step 3: Convert PQR Back to PDB Using Open Babel
OUTPUT_PDB="${OUTPUT_PQR%.pqr}_converted.pdb"
echo "Step 3: Converting PQR back to PDB using Open Babel..."
obabel "$OUTPUT_PQR" -O "$OUTPUT_PDB"

if [ $? -eq 0 ]; then
    echo "Conversion successful. PDB file saved as $OUTPUT_PDB"
else
    echo "Error during conversion with Open Babel. Check the PQR file format."
    exit 1
fi

