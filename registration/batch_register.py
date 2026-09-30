import os
import sys
import subprocess


# -----------------------------------
# Configuration
# -----------------------------------

DATA_FOLDER = "../data"


# -----------------------------------
# Find all pair folders
# -----------------------------------

pair_folders = []

for name in os.listdir(DATA_FOLDER):

    full_path = os.path.join(DATA_FOLDER, name)

    if os.path.isdir(full_path) and name.startswith("pair_"):
        pair_folders.append(name)


# Sort pairs numerically
pair_folders.sort(
    key=lambda x: int(x.split("_")[1])
)


# -----------------------------------
# Check whether pairs exist
# -----------------------------------

if len(pair_folders) == 0:

    print("ERROR: No pair folders found.")
    print("Expected folders such as:")
    print("pair_012")
    print("pair_013")

    sys.exit()


print("========================================")
print("BATCH REGISTRATION")
print("========================================")

print("Pairs found:", len(pair_folders))

for pair in pair_folders:
    print(" -", pair)


# -----------------------------------
# Process every pair
# -----------------------------------

for pair in pair_folders:

    print("")
    print("========================================")
    print("Processing:", pair)
    print("========================================")

    result = subprocess.run(
        [
            sys.executable,
            "register.py",
            pair
        ]
    )

    if result.returncode != 0:

        print("")
        print("ERROR while processing:", pair)
        print("Skipping this pair.")

        continue


# -----------------------------------
# Complete
# -----------------------------------

print("")
print("========================================")
print("BATCH REGISTRATION COMPLETE")
print("========================================")