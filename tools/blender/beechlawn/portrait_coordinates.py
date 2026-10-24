"""Eye-line coordinates in units of interpupillary distance, with Y upward."""
import numpy as np


def eye_coordinates(points, left_index=468, right_index=473):
    points = np.asarray(points, dtype=float)[..., :2]
    left, right = points[left_index], points[right_index]
    if left[0] > right[0]:
        left, right = right, left
    centre = (left + right) * .5
    axis = right - left
    distance = np.linalg.norm(axis)
    if distance < 1e-6:
        raise ValueError('Coincident eye centres')
    c, s = axis / distance
    # Columns project onto the eye axis and its upward perpendicular.
    # The previous opposite-sign matrix doubled, rather than removed, roll.
    transform = np.array([[c, s], [s, -c]])
    return (points - centre) @ transform / distance
