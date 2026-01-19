# 🔧 Fix: Multiple Commands Produce Info.plist

## The Problem

Xcode is showing this error:
```
Multiple commands produce '/Users/.../Dobby.app/Info.plist'
```

This means **two or more build phases are trying to create or copy the same Info.plist file**.

## Root Causes

This typically happens when:

1. ✅ **Info.plist is in "Copy Bundle Resources"** (it shouldn't be!)
2. ✅ **Multiple targets share the same Info.plist**
3. ✅ **Build settings conflict**
4. ✅ **Duplicate file references** in project

---

## 🎯 Solution 1: Remove Info.plist from Copy Bundle Resources (MOST COMMON)

This is the #1 cause and easiest fix:

### Steps:

1. **In Xcode, select your project** (blue icon at top of navigator)

2. **Select the "Dobby" target** (in the TARGETS list)

3. **Click "Build Phases" tab** at the top

4. **Expand "Copy Bundle Resources"** section

5. **Look for "Info.plist" in the list**

6. **If you see Info.plist there:**
   - Select it
   - Click the **"-"** button to remove it
   - ⚠️ **DO NOT delete the file itself**, just remove it from this list

7. **Repeat for ANY Share Extension or other targets:**
   - Select "Dobby Share Extension" target (if you have one)
   - Build Phases → Copy Bundle Resources
   - Remove Info.plist if present

8. **Clean Build Folder**: Product → Clean Build Folder (Cmd+Shift+K)

9. **Build**: Product → Build (Cmd+B)

✅ **This should fix the error immediately!**

---

## 🎯 Solution 2: Check for Duplicate File References

Sometimes the project has duplicate references to the same Info.plist:

### Steps:

1. **In Xcode Project Navigator**, search for "Info.plist"

2. **Count how many times it appears**
   - Main app should have: `Dobby/Info.plist`
   - Share extension should have: `Dobby Share Extension/Info.plist`
   - Each should appear **only once**

3. **If you see duplicates:**
   - Right-click on the duplicate → **Delete**
   - Choose **Remove Reference** (NOT "Move to Trash")

4. **Clean and Build**

---

## 🎯 Solution 3: Check Build Settings

Ensure build settings are correct:

### Steps:

1. **Select your project** → **Dobby target** → **Build Settings**

2. **Search for**: `INFOPLIST_FILE`

3. **Check the value:**
   - For main app: should be `Dobby/Info.plist` or `$(SRCROOT)/Dobby/Info.plist`
   - For Share Extension: should be `Dobby Share Extension/Info.plist`

4. **If it's wrong or has multiple values:**
   - Click on the setting
   - Delete incorrect values
   - Set the correct path

5. **Clean and Build**

---

## 🎯 Solution 4: Generate Info.plist (Modern Xcode)

For newer Xcode versions, you can let Xcode generate Info.plist:

### Steps:

1. **Select target** → **Build Settings**

2. **Search for**: `Generate Info.plist File`

3. **Set to**: `Yes`

4. **Search for**: `INFOPLIST_FILE`

5. **Delete the value** (leave it empty)

6. **Move your custom Info.plist entries to Build Settings:**
   - Camera usage description
   - Photo library usage description
   - etc.

7. **Clean and Build**

⚠️ **This is more advanced** and requires migrating custom keys to build settings.

---

## 🎯 Solution 5: Clean DerivedData (Nuclear Option)

If nothing else works:

### Steps:

1. **Close Xcode completely**

2. **Open Finder**

3. **Go → Go to Folder** (Cmd+Shift+G)

4. **Type**: `~/Library/Developer/Xcode/DerivedData`

5. **Find folder starting with "Dobby-"**

6. **Delete it** (move to trash)

7. **Open Xcode again**

8. **Clean Build Folder** (Cmd+Shift+K)

9. **Build** (Cmd+B)

---

## 🔍 Verify the Fix

After applying a solution:

### Check Build Phases:

1. **Project → Target → Build Phases**
2. **"Copy Bundle Resources"** should NOT contain Info.plist
3. **"Compile Sources"** should contain your .swift files
4. **"Link Binary With Libraries"** should contain frameworks

### Check File Location:

1. Info.plist should be in your project folder
2. NOT in Build or DerivedData folders
3. Each target should have its own Info.plist

---

## 🎯 Most Likely Fix for Your Project

Based on your error and the fact you have a Share Extension:

### Quick Steps:

1. **Project → Dobby target → Build Phases**
2. **Copy Bundle Resources → Remove Info.plist**
3. **Project → Dobby Share Extension target → Build Phases**
4. **Copy Bundle Resources → Remove Info.plist**
5. **Clean Build Folder** (Cmd+Shift+K)
6. **Build** (Cmd+B)

---

## Still Not Working?

### Advanced Debugging:

1. **View the full error** in the build log:
   - Product → Build (it will fail)
   - Click on the error in the Issue Navigator
   - Look for "Target 'X'" lines showing which targets are conflicting

2. **Check both commands** mentioned in the error:
   - The error will show "Target 'Dobby': command A"
   - And "Target 'Dobby': command B"
   - This tells you exactly which build phases are conflicting

3. **Disable one at a time:**
   - Build Phases → Right-click on suspicious phase → Disable
   - Try building
   - Repeat to isolate the problem

---

## Summary

**The fix is almost always:** Remove Info.plist from "Copy Bundle Resources" build phase.

Info.plist is **automatically** included in your app bundle by Xcode. You should **never** manually copy it in a build phase.

After removing it from Copy Bundle Resources and cleaning, the error will disappear! 🎉

---

## Why This Happens

When you create targets or import files, Xcode sometimes automatically adds Info.plist to the "Copy Bundle Resources" phase. This creates a conflict because:

1. Xcode **automatically** processes Info.plist (Command 1)
2. Copy Bundle Resources **also** tries to copy it (Command 2)
3. Both commands try to create the same file in the app bundle
4. Build fails with "Multiple commands produce..."

The solution is to let Xcode handle Info.plist automatically and remove it from manual copy operations.

---

**Follow Solution 1 above and your build will succeed! 🚀**
