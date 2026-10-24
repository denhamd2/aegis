"""Regression: remove portrait roll, retaining normalized facial proportions."""
import unittest
import numpy as np
from portrait_coordinates import eye_coordinates


class PortraitCoordinatesTests(unittest.TestCase):
    def test_roll_invariance(self):
        canonical = np.array([[-.5, 0], [.5, 0], [.12, -.68], [0, -1.6]])
        for angle in (-.4, 0, .2, .55):
            c, s = np.cos(angle), np.sin(angle)
            pixels = canonical @ np.array([[c, s], [s, -c]]) * 137 + (287, 431)
            normalized = eye_coordinates(pixels, 0, 1)
            np.testing.assert_allclose(normalized, canonical, atol=1e-12)
            np.testing.assert_allclose(normalized[:2, 1], 0, atol=1e-12)

    def test_degenerate_eyes_rejected(self):
        with self.assertRaises(ValueError):
            eye_coordinates(np.ones((2, 2)), 0, 1)


if __name__ == '__main__':
    unittest.main()
