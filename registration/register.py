import cv2
import numpy as np
import json
import sys
import os
import re
# -----------------------------
# Spatial coverage function
# -----------------------------

def calculate_spatial_coverage(points, width, height, grid_rows=4, grid_cols=4):

    covered_cells = set()

    for point in points:

        x = float(point[0])
        y = float(point[1])

        col = int(x / width * grid_cols)
        row = int(y / height * grid_rows)

        # Keep points inside the grid
        col = max(0, min(col, grid_cols - 1))
        row = max(0, min(row, grid_rows - 1))

        covered_cells.add((row, col))

    total_cells = grid_rows * grid_cols

    coverage_percent = (
        len(covered_cells) / total_cells
    ) * 100.0

    return len(covered_cells), total_cells, coverage_percent
# -----------------------------
# File paths
# -----------------------------

# -----------------------------
# Select experiment pair
# -----------------------------

if len(sys.argv) < 2:

    print("ERROR: Please specify a pair.")
    print("Example:")
    print("python register.py pair_004")
    exit()

pair_id = sys.argv[1]

# -----------------------------
# Validate pair ID
# -----------------------------

if not re.fullmatch(r"pair_\d+", pair_id):

    print("ERROR: Invalid pair ID.")
    print("Pair ID must look like:")
    print("pair_004")
    print("pair_005")
    print("pair_123")
    exit()


print("Processing:", pair_id)


# -----------------------------
# File paths
# -----------------------------

pair_folder = os.path.join(
    "..",
    "data",
    pair_id
)

image_a_path = os.path.join(
    pair_folder,
    "image_A.png"
)

image_b_path = os.path.join(
    pair_folder,
    "image_B.png"
)

affine_output_path = os.path.join(
    pair_folder,
    "affine_registered_B.png"
)

homography_output_path = os.path.join(
    pair_folder,
    "registered_B.png"
)

metrics_output_path = os.path.join(
    pair_folder,
    "metrics.json"
)

# -----------------------------
# Load ground truth
# -----------------------------

ground_truth_path = os.path.join(
    pair_folder,
    "ground_truth.json"
)

ground_truth = None

if os.path.exists(ground_truth_path):

    try:

        with open(
            ground_truth_path,
            "r"
        ) as ground_truth_file:

            ground_truth = json.load(
                ground_truth_file
            )

        print("Ground truth loaded successfully.")

    except Exception as error:

        print("WARNING: Could not read ground truth.")
        print("Reason:", error)

else:

    print("WARNING: Ground truth file not found.")
# -----------------------------
# Load images
# -----------------------------

image_a = cv2.imread(image_a_path)
image_b = cv2.imread(image_b_path)

if image_a is None:
    print("ERROR: Could not load Image A")
    print(image_a_path)
    exit()

if image_b is None:
    print("ERROR: Could not load Image B")
    print(image_b_path)
    exit()


print("Images loaded successfully.")

print("Image A size:", image_a.shape)
print("Image B size:", image_b.shape)


# -----------------------------
# Convert to grayscale
# -----------------------------

gray_a = cv2.cvtColor(image_a, cv2.COLOR_BGR2GRAY)
gray_b = cv2.cvtColor(image_b, cv2.COLOR_BGR2GRAY)


# -----------------------------
# Detect features
# -----------------------------

clahe = cv2.createCLAHE(
    clipLimit=2.0,
    tileGridSize=(8, 8)
)

enhanced_a = clahe.apply(gray_a)
enhanced_b = clahe.apply(gray_b)


sift = cv2.SIFT_create(
    nfeatures=2000,
    contrastThreshold=0.01
)


keypoints_a, descriptors_a = sift.detectAndCompute(
    enhanced_a,
    None
)

keypoints_b, descriptors_b = sift.detectAndCompute(
    enhanced_b,
    None
)


print("Features in Image A:", len(keypoints_a))
print("Features in Image B:", len(keypoints_b))


# -----------------------------
# Match features
# -----------------------------

matcher = cv2.BFMatcher()

matches = matcher.knnMatch(
    descriptors_a,
    descriptors_b,
    k=2
)


# -----------------------------
# Lowe's ratio test
# -----------------------------

good_matches = []

for m, n in matches:

    if m.distance < 0.80 * n.distance:
        good_matches.append(m)


print("Total matches:", len(matches))
print("Good matches:", len(good_matches))


# -----------------------------
# Check enough matches
# -----------------------------

if len(good_matches) < 4:

    print("ERROR: Not enough good matches.")
    print("Registration cannot be estimated.")

    exit()


# -----------------------------
# Extract matched points
# -----------------------------

points_a = np.float32(
    [keypoints_a[m.queryIdx].pt for m in good_matches]
)

points_b = np.float32(
    [keypoints_b[m.trainIdx].pt for m in good_matches]
)


# ============================================================
# AFFINE TRANSFORMATION
# ============================================================

print("")
print("================================")
print("AFFINE TRANSFORMATION")
print("================================")


affine_matrix, affine_mask = cv2.estimateAffine2D(
    points_b,
    points_a,
    method=cv2.RANSAC,
    ransacReprojThreshold=5.0,
    maxIters=2000,
    confidence=0.99
)


if affine_matrix is None or affine_mask is None:

    print("ERROR: Could not estimate affine transformation.")
    exit()


affine_mask = affine_mask.ravel()

affine_inliers = int(
    np.sum(affine_mask)
)


affine_inlier_ratio = (
    affine_inliers / len(good_matches)
)


print("Affine matrix:")
print(affine_matrix)

print(
    "Affine inliers:",
    affine_inliers
)

print(
    "Affine inlier ratio: %.2f%%"
    % (affine_inlier_ratio * 100.0)
)


# -----------------------------
# Affine reprojection error
# -----------------------------

affine_projected_points = cv2.transform(
    points_b.reshape(-1, 1, 2),
    affine_matrix
).reshape(-1, 2)


affine_errors = np.linalg.norm(
    affine_projected_points
    -
    points_a,
    axis=1
)


affine_inlier_errors = affine_errors[
    affine_mask == 1
]
# -----------------------------------
# Affine spatial coverage
# -----------------------------------

affine_inlier_points = points_a[
    affine_mask == 1
]

affine_covered_cells, affine_total_cells, affine_coverage = (
    calculate_spatial_coverage(
        affine_inlier_points,
        width=image_a.shape[1],
        height=image_a.shape[0]
    )
)

print(
    "Affine spatial coverage: %.2f%%"
    % affine_coverage
)

print(
    "Affine covered cells: %d / %d"
    % (affine_covered_cells, affine_total_cells)
)

affine_mean_error = float(
    np.mean(affine_inlier_errors)
)

affine_median_error = float(
    np.median(affine_inlier_errors)
)

affine_rmse = float(
    np.sqrt(
        np.mean(
            affine_inlier_errors ** 2
        )
    )
)

affine_max_error = float(
    np.max(affine_inlier_errors)
)


print(
    "Affine mean reprojection error: %.3f pixels"
    % affine_mean_error
)

print(
    "Affine median reprojection error: %.3f pixels"
    % affine_median_error
)

print(
    "Affine RMSE: %.3f pixels"
    % affine_rmse
)

print(
    "Affine maximum error: %.3f pixels"
    % affine_max_error
)


# -----------------------------
# Affine sub-pixel percentages
# -----------------------------

affine_under_1 = float(
    np.mean(affine_inlier_errors < 1.0) * 100.0
)

affine_under_05 = float(
    np.mean(affine_inlier_errors < 0.5) * 100.0
)

affine_under_025 = float(
    np.mean(affine_inlier_errors < 0.25) * 100.0
)


print(
    "Affine error < 1.0 px: %.2f%%"
    % affine_under_1
)

print(
    "Affine error < 0.5 px: %.2f%%"
    % affine_under_05
)

print(
    "Affine error < 0.25 px: %.2f%%"
    % affine_under_025
)


# -----------------------------
# Warp Image B using affine
# -----------------------------

height, width = gray_a.shape

affine_registered_b = cv2.warpAffine(
    image_b,
    affine_matrix,
    (width, height)
)


cv2.imwrite(
    affine_output_path,
    affine_registered_b
)


print("")
print("Saved affine registered image to:")
print(affine_output_path)


# ============================================================
# HOMOGRAPHY TRANSFORMATION
# ============================================================

print("")
print("================================")
print("HOMOGRAPHY TRANSFORMATION")
print("================================")


homography_points_a = points_a.reshape(-1, 1, 2)
homography_points_b = points_b.reshape(-1, 1, 2)


H, homography_mask = cv2.findHomography(
    homography_points_b,
    homography_points_a,
    cv2.RANSAC,
    5.0
)


if H is None or homography_mask is None:

    print("ERROR: Could not estimate homography.")
    exit()


homography_mask = homography_mask.ravel()


homography_inliers = int(
    np.sum(homography_mask)
)


homography_inlier_ratio = (
    homography_inliers / len(good_matches)
)


print("Homography matrix:")
print(H)

print(
    "Homography inliers:",
    homography_inliers
)

print(
    "Homography inlier ratio: %.2f%%"
    % (homography_inlier_ratio * 100.0)
)


# -----------------------------
# Homography reprojection error
# -----------------------------

homography_projected_points = cv2.perspectiveTransform(
    homography_points_b,
    H
).reshape(-1, 2)


homography_errors = np.linalg.norm(
    homography_projected_points
    -
    points_a,
    axis=1
)


homography_inlier_errors = homography_errors[
    homography_mask == 1
]
# -----------------------------------
# Homography spatial coverage
# -----------------------------------

homography_inlier_points = points_a[
    homography_mask == 1
]

homography_covered_cells, homography_total_cells, homography_coverage = (
    calculate_spatial_coverage(
        homography_inlier_points,
        width=image_a.shape[1],
        height=image_a.shape[0]
    )
)

print(
    "Homography spatial coverage: %.2f%%"
    % homography_coverage
)

print(
    "Homography covered cells: %d / %d"
    % (homography_covered_cells, homography_total_cells)
)

homography_mean_error = float(
    np.mean(homography_inlier_errors)
)

homography_median_error = float(
    np.median(homography_inlier_errors)
)

homography_rmse = float(
    np.sqrt(
        np.mean(
            homography_inlier_errors ** 2
        )
    )
)

homography_max_error = float(
    np.max(homography_inlier_errors)
)


print(
    "Homography mean reprojection error: %.3f pixels"
    % homography_mean_error
)

print(
    "Homography median reprojection error: %.3f pixels"
    % homography_median_error
)

print(
    "Homography RMSE: %.3f pixels"
    % homography_rmse
)

print(
    "Homography maximum error: %.3f pixels"
    % homography_max_error
)


# -----------------------------
# Homography sub-pixel percentages
# -----------------------------

homography_under_1 = float(
    np.mean(homography_inlier_errors < 1.0) * 100.0
)

homography_under_05 = float(
    np.mean(homography_inlier_errors < 0.5) * 100.0
)

homography_under_025 = float(
    np.mean(homography_inlier_errors < 0.25) * 100.0
)


print(
    "Homography error < 1.0 px: %.2f%%"
    % homography_under_1
)

print(
    "Homography error < 0.5 px: %.2f%%"
    % homography_under_05
)

print(
    "Homography error < 0.25 px: %.2f%%"
    % homography_under_025
)


# -----------------------------
# Warp Image B using homography
# -----------------------------

homography_registered_b = cv2.warpPerspective(
    image_b,
    H,
    (width, height)
)


cv2.imwrite(
    homography_output_path,
    homography_registered_b
)


print("")
print("Saved homography registered image to:")
print(homography_output_path)


# ============================================================
# SAVE METRICS
# ============================================================

metrics = {
    "pair": pair_id,

    "ground_truth": ground_truth,

    "image_size": {
        "width": int(width),
        "height": int(height)
    },

    "feature_detection": {
        "features_image_A": len(keypoints_a),
        "features_image_B": len(keypoints_b)
    },

    "matching": {
        "total_matches": len(matches),
        "good_matches": len(good_matches),
        "lowe_ratio": 0.80
    },

    "sift": {
        "nfeatures": 2000,
        "contrast_threshold": 0.01,
        "clahe_clip_limit": 2.0,
        "clahe_tile_grid_size": [8, 8]
    },

    "affine": {
        "inliers": affine_inliers,
        "inlier_ratio": affine_inlier_ratio,
            "spatial_coverage_percent": affine_coverage,
    "spatial_coverage_cells": affine_covered_cells,
        "mean_reprojection_error_px": affine_mean_error,
        "median_reprojection_error_px": affine_median_error,
        "rmse_px": affine_rmse,
        "maximum_error_px": affine_max_error,
        "error_under_1px_percent": affine_under_1,
        "error_under_0_5px_percent": affine_under_05,
        "error_under_0_25px_percent": affine_under_025,
        "matrix": affine_matrix.tolist()
    },

    "homography": {
        "inliers": homography_inliers,
        "inlier_ratio": homography_inlier_ratio,
            "spatial_coverage_percent": homography_coverage,
    "spatial_coverage_cells": homography_covered_cells,
        "mean_reprojection_error_px": homography_mean_error,
        "median_reprojection_error_px": homography_median_error,
        "rmse_px": homography_rmse,
        "maximum_error_px": homography_max_error,
        "error_under_1px_percent": homography_under_1,
        "error_under_0_5px_percent": homography_under_05,
        "error_under_0_25px_percent": homography_under_025,
        "matrix": H.tolist()
    },

   "notes": {
    "metric_type": "feature_reprojection_error",
    "ground_truth_camera_geometry_available": ground_truth is not None,
    "ground_truth_pixel_correspondence_available": False,
    "subpixel_values_are_not_true_ground_truth_accuracy": True
}
}


with open(
    metrics_output_path,
    "w"
) as metrics_file:

    json.dump(
        metrics,
        metrics_file,
        indent=4
    )


print("")
print("================================")
print("METRICS SAVED")
print("================================")
print(metrics_output_path)

print("")
print("================================")
print("REGISTRATION BASELINE COMPLETE")
print("================================")