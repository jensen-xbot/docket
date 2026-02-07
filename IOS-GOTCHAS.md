# iOS Development Gotchas

Critical issues and fixes discovered during Docket development.

---

## Issue #2: Build Error - No AppIcon Found

**Symptom:** Build fails with error:
```
None of the input catalogs contained a matching stickers icon set, 
app icon set, or icon stack named "AppIcon".
```

**Root Cause:** Build settings reference `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` but no icon set exists in Assets.xcassets.

**Fix:** Create `Assets.xcassets/AppIcon.appiconset/` with `Contents.json`:

```json
{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

**Note:** Empty icon set satisfies Xcode build. Add real 1024x1024 icon later.

**Required After Fix:**
1. Clean Build Folder (Shift+Cmd+K)
2. Run again (Cmd+R)

**Discovered:** 2026-02-07 via Opus 4.6 analysis

---

## Issue #1: App Shows Black Bars / Letterboxed (iPhone 4 Look)

**Symptom:** App runs with black bars on top/bottom or sides, looks like iPhone 4-era app floating in a small card.

**Root Cause:** Missing `INFOPLIST_KEY_UILaunchScreen_Generation = YES` in build settings. Without this, iOS assumes the app was built for older screen sizes and runs it in legacy compatibility mode.

**Fix:** Add to project.pbxproj buildSettings (both Debug and Release):

```
INFOPLIST_KEY_UILaunchScreen_Generation = YES;
INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
INFOPLIST_KEY_CFBundleDisplayName = Docket;
INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
```

**Required After Fix:**
1. Delete app from simulator/device
2. Clean build: Product → Clean Build Folder (Shift+Cmd+K)
3. Run again (Cmd+R)

**Result:** App fills entire screen edge-to-edge.

**Discovered:** 2026-02-07 via Opus 4.6 analysis

---

## Prevention Checklist

For all future iOS projects, verify in project.pbxproj:

- [ ] `INFOPLIST_KEY_UILaunchScreen_Generation = YES`
- [ ] `INFOPLIST_KEY_UISupportedInterfaceOrientations` set appropriately
- [ ] `GENERATE_INFOPLIST_FILE = YES` (if using modern Xcode)
- [ ] `IPHONEOS_DEPLOYMENT_TARGET` matches intended version

---

*Document lessons learned to prevent repeating mistakes*