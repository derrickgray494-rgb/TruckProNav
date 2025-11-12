# Adding Background Image to Login Screen

## Steps to Add Your Truck Background Image

1. **Prepare the Image**
   - Take the truck image you want to use (without the text overlay)
   - Save it as a PNG or JPG file
   - Recommended resolution: 1125x2436 (iPhone X) or higher for best quality

2. **Add to Xcode Assets**
   - Open `TrucknavPro.xcodeproj` in Xcode
   - In the Project Navigator (left sidebar), find `Assets.xcassets`
   - Click on `Assets.xcassets` to open it
   - Right-click in the assets list and select **"New Image Set"**
   - Rename the new image set to: `truck_background`
   - Drag your truck image file into the **"Any"** or **"Universal"** box
   - The image should appear in the asset catalog

3. **Run the App**
   - Build and run the app (Cmd + R)
   - The login screen should now show your truck image as the background
   - The form elements will appear on top with a dark semi-transparent overlay

## What Was Changed

- **LoginView.swift** (SwiftUI) now has:
  - Background image view (`truck_background` from Assets)
  - Dark overlay (45% opacity) for better text readability
  - White text labels and title with shadow effects
  - Custom text fields with icons and focus states
  - Gradient sign in button (orange to steel blue)
  - All UI elements are visible on the dark truck background

## Customization Options

If you want to adjust the overlay darkness, edit this line in `LoginView.swift`:

```swift
.overlay(Color.black.opacity(0.45)) // dark overlay for contrast
```

Change `0.45` to:
- `0.3` = Lighter overlay (more image visible)
- `0.5` = Darker overlay (better text contrast)
- `0.6` = Very dark overlay

### Color Customization

The login screen uses custom accent colors:
```swift
private let accent = Color(red: 0.85, green: 0.25, blue: 0.2) // orange-red
private let steelBlue = Color(red: 0.10, green: 0.17, blue: 0.25)
```

You can adjust these colors to match your branding.

## Troubleshooting

**If the image doesn't appear:**
1. Make sure the image set is named exactly: `truck_background` (no spaces, lowercase)
2. Make sure the image is assigned to "Any" or "Universal" appearance
3. Clean build folder: Product → Clean Build Folder (Cmd + Shift + K)
4. Rebuild the project (Cmd + B)

**If text is hard to read:**
- Increase the overlay darkness (see Customization Options above)
- Or change `.scaledToFill()` to `.scaledToFit()` if you want to see more of the image

---

✅ **Build Status:** Successful - SwiftUI login screen ready!

**Design:** Modern SwiftUI with custom components and gradient buttons
