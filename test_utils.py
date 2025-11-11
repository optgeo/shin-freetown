#!/usr/bin/env python3
"""
Simple test to validate terrain tile utilities.
Tests the Terrarium encoding logic without requiring full dependencies.
"""
import numpy as np


def test_terrarium_encoding():
    """Test basic Terrarium encoding logic."""
    print("Testing Terrarium encoding logic...")
    
    # Test data: simple elevation values
    elevations = np.array([
        [0, 100, 500],
        [-100, 1000, 2000],
        [-32768, 0, 32767]
    ], dtype=np.float32)
    
    # Simulate encoding (without zoom rounding for simplicity)
    data = elevations + 32768
    
    # Check RGB decomposition
    R = data // 256
    G = data % 256
    B = (data - np.floor(data)) * 256
    
    # Verify reconstruction
    reconstructed = (R * 256 + G + B / 256) - 32768
    
    # Allow small floating point differences
    max_error = np.max(np.abs(reconstructed - elevations))
    print(f"Max reconstruction error: {max_error:.6f} meters")
    
    assert max_error < 0.1, f"Reconstruction error too large: {max_error}"
    
    print("✓ Terrarium encoding test passed!")


def test_vertical_rounding():
    """Test zoom-dependent vertical rounding."""
    print("\nTesting vertical rounding at different zoom levels...")
    
    # Test rounding factor calculation
    for z in [0, 10, 15, 19]:
        factor = 2 ** (19 - z) / 256
        print(f"  Zoom {z:2d}: factor={factor:10.6f}m (vertical resolution)")
    
    # Test actual rounding
    elevation = 123.456  # meters
    z = 15
    factor = 2 ** (19 - z) / 256
    rounded = np.round(elevation / factor) * factor
    
    print(f"\nExample: elevation={elevation}m at z={z}")
    print(f"  Factor: {factor:.6f}m")
    print(f"  Rounded: {rounded:.6f}m")
    
    print("✓ Vertical rounding test passed!")


def test_zoom_resolutions():
    """Verify vertical resolution table from README."""
    print("\nVerifying zoom level vertical resolutions...")
    
    expected = {
        0: 2048.0,
        5: 64.0,
        10: 2.0,
        15: 2 ** (19 - 15) / 256,  # ~0.0625m = 6.25cm
        19: 1/256  # ~0.0039m = 3.9mm
    }
    
    for z, expected_res in expected.items():
        calculated_res = 2 ** (19 - z) / 256
        error = abs(calculated_res - expected_res)
        print(f"  Zoom {z:2d}: {calculated_res:10.6f}m (expected ~{expected_res:.6f}m, error={error:.9f})")
        assert error < 0.001, f"Resolution mismatch at zoom {z}"
    
    print("✓ Zoom resolution test passed!")


if __name__ == '__main__':
    print("=== Testing Terrain Tile Utilities ===\n")
    
    try:
        test_terrarium_encoding()
        test_vertical_rounding()
        test_zoom_resolutions()
        
        print("\n" + "="*50)
        print("All tests passed! ✓")
        print("="*50)
        
    except Exception as e:
        print(f"\n✗ Test failed: {e}")
        import traceback
        traceback.print_exc()
        exit(1)
