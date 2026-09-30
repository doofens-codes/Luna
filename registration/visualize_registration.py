import cv2
import numpy as np
import sys
import os
# -----------------------------------
# Get pair name from command line
# -----------------------------------

if len(sys.argv) < 2:

    print("ERROR: Please provide a pair name.")
    print("Example:")
    print("python visualize_registration.py pair_002")
    sys.exit()


pair_name = sys.argv[1]

print("Processing:", pair_name)


# -----------------------------------
# File paths
# -----------------------------------

pair_folder = os.path.join(
    "..",
    "data",
    pair_name
)
if not os.path.isdir(pair_folder):

    print("ERROR: Pair folder does not exist.")
    print("Expected folder:", pair_folder)

    sys.exit()


image_a_path = os.path.join(
    pair_folder,
    "image_A.png"
)


image_b_path = os.path.join(
    pair_folder,
    "image_B.png"
)


matches_output = os.path.join(
    pair_folder,
    "matches.png"
)


overlay_output = os.path.join(
    pair_folder,
    "overlay.png"
)


affine_overlay_output = os.path.join(
    pair_folder,
    "affine_overlay.png"
)


inlier_points_output = os.path.join(
    pair_folder,
    "inlier_points.png"
)

# -----------------------------------
# Load images
# -----------------------------------

image_a = cv2.imread(image_a_path)
image_b = cv2.imread(image_b_path)

if image_a is None:
    print("ERROR: Could not load Image A")
    exit()

if image_b is None:
    print("ERROR: Could not load Image B")
    exit()


print("Images loaded successfully.")


# -----------------------------------
# Convert to grayscale
# -----------------------------------

gray_a = cv2.cvtColor(image_a, cv2.COLOR_BGR2GRAY)
gray_b = cv2.cvtColor(image_b, cv2.COLOR_BGR2GRAY)


# -----------------------------------
# Detect SIFT features
# -----------------------------------

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


# -----------------------------------
# Match features
# -----------------------------------

matcher = cv2.BFMatcher()

matches = matcher.knnMatch(
    descriptors_a,
    descriptors_b,
    k=2
)


# -----------------------------------
# Lowe ratio test
# -----------------------------------

good_matches = []

for m, n in matches:

    if m.distance < 0.80 * n.distance:
        good_matches.append(m)


print("Good matches:", len(good_matches))


# -----------------------------------
# Check enough matches exist
# -----------------------------------

if len(good_matches) < 4:
    print("ERROR: Not enough good matches for homography.")
    exit()


# -----------------------------------
# Prepare matched points
# -----------------------------------

points_a = np.float32(
    [keypoints_a[m.queryIdx].pt for m in good_matches]
).reshape(-1, 1, 2)

points_b = np.float32(
    [keypoints_b[m.trainIdx].pt for m in good_matches]
).reshape(-1, 1, 2)


# -----------------------------------
# Estimate homography
# -----------------------------------

H, mask = cv2.findHomography(
    points_b,
    points_a,
    cv2.RANSAC,
    5.0
)

if H is None or mask is None:
    print("ERROR: Could not estimate homography.")
    exit()


# -----------------------------------
# Estimate affine transformation
# -----------------------------------

affine_matrix, affine_mask = cv2.estimateAffine2D(
    points_b.reshape(-1, 2),
    points_a.reshape(-1, 2),
    method=cv2.RANSAC,
    ransacReprojThreshold=5.0,
    maxIters=2000,
    confidence=0.99
)


if affine_matrix is None:
    print("ERROR: Could not estimate affine transformation.")
    exit()


print("Affine transformation estimated.")



# -----------------------------------
# Extract RANSAC inliers
# -----------------------------------

mask = mask.ravel()

inlier_matches = []

inlier_points_a = []
inlier_points_b = []

for i, m in enumerate(good_matches):

    if mask[i] == 1:

        inlier_matches.append(m)

        inlier_points_a.append(
            keypoints_a[m.queryIdx].pt
        )

        inlier_points_b.append(
            keypoints_b[m.trainIdx].pt
        )


print("RANSAC inliers:", len(inlier_matches))


# -----------------------------------
# Inlier ratio
# -----------------------------------

inlier_ratio = (
    len(inlier_matches) / len(good_matches)
    if len(good_matches) > 0
    else 0.0
)

print(
    "Inlier ratio: %.2f%%"
    % (inlier_ratio * 100.0)
)


# -----------------------------------
# Print homography
# -----------------------------------

print("--------------------------------")
print("Estimated Homography:")
print(H)
print("--------------------------------")


# -----------------------------------
# Calculate reprojection error
# -----------------------------------

inlier_points_a_array = np.float32(
    inlier_points_a
).reshape(-1, 1, 2)

inlier_points_b_array = np.float32(
    inlier_points_b
).reshape(-1, 1, 2)


projected_points = cv2.perspectiveTransform(
    inlier_points_b_array,
    H
)


errors = np.linalg.norm(
    projected_points.reshape(-1, 2)
    -
    inlier_points_a_array.reshape(-1, 2),
    axis=1
)


if len(errors) > 0:

    mean_error = float(np.mean(errors))
    median_error = float(np.median(errors))
    rmse = float(np.sqrt(np.mean(errors ** 2)))
    max_error = float(np.max(errors))

    print("Reprojection error:")
    print("Mean error: %.3f pixels" % mean_error)
    print("Median error: %.3f pixels" % median_error)
    print("RMSE: %.3f pixels" % rmse)
    print("Maximum error: %.3f pixels" % max_error)

else:

    print("Could not calculate reprojection error.")


# -----------------------------------
# Draw only RANSAC inlier matches
# -----------------------------------

match_image = cv2.drawMatches(
    image_a,
    keypoints_a,
    image_b,
    keypoints_b,
    inlier_matches,
    None,
    flags=cv2.DrawMatchesFlags_NOT_DRAW_SINGLE_POINTS
)


# -----------------------------------
# Save match visualization
# -----------------------------------

cv2.imwrite(
    matches_output,
    match_image
)

print("Saved match visualization:")
print(matches_output)


# -----------------------------------
# Draw inlier points on Image A
# -----------------------------------

inlier_points_image = image_a.copy()

for point in inlier_points_a:

    x = int(round(point[0]))
    y = int(round(point[1]))

    cv2.circle(
        inlier_points_image,
        (x, y),
        5,
        (0, 255, 0),
        -1
    )


cv2.imwrite(
    inlier_points_output,
    inlier_points_image
)

print("Saved inlier point visualization:")
print(inlier_points_output)


# -----------------------------------
# Warp Image B
# -----------------------------------

height, width = image_a.shape[:2]

registered_b = cv2.warpPerspective(
    image_b,
    H,
    (width, height)
)

# -----------------------------------
# Warp Image B using affine matrix
# -----------------------------------

affine_registered_b = cv2.warpAffine(
    image_b,
    affine_matrix,
    (width, height)
)
# -----------------------------------
# Create overlay
# -----------------------------------

overlay = cv2.addWeighted(
    image_a,
    0.5,
    registered_b,
    0.5,
    0
)

# -----------------------------------
# Create affine overlay
# -----------------------------------

affine_overlay = cv2.addWeighted(
    image_a,
    0.5,
    affine_registered_b,
    0.5,
    0
)


# -----------------------------------
# Save overlay
# -----------------------------------

cv2.imwrite(
    overlay_output,
    overlay
)

print("Saved overlay:")
print(overlay_output)

cv2.imwrite(
    affine_overlay_output,
    affine_overlay
)

print("Saved affine overlay:")
print(affine_overlay_output)

# -----------------------------------
# Final summary
# -----------------------------------

print("================================")
print("VISUALIZATION COMPLETE")
print("================================")