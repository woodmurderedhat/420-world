# Usability & UI/UX Improvement Tasklist

## 🔴 High Priority (Core Experience)

### Shell Experience

- [ ] **Taskbar Clock & Date**: Add a clock module to the far right of the taskbar.
- [ ] **Start Menu Experience**:
  - [ ] Make sure the Start Menu Displays properly. Currently its not visible at all I suspect due to placement.
  - [ ] Implement keyboard navigation (Arrow keys + Enter to launch).
  - [ ] Add "Session Control" buttons (Exit Game/Shutdown, Restart).
  - [ ] Add user profile section (Avatar + Name placeholder).
- [ ] **Volume/System Tray**: Create a basic generic "Tray" container for system status icons.
- [ ] **Desktop Interactions**:
  - [ ] Right-click context menu on desktop (Change Theme, Refresh, etc.).
  - [ ] Desktop icons/shortcuts system (drag apps from start menu to desktop and into ihe taskbar. Separate the taskbar into its own resizable section. .

### Window Management

- [ ] **Visual Window Snapping**: Show a semi-transparent "ghost" rectangle when dragging a window near screen edges (Aero Snap style).
- [ ] **Input Polish**:
  - [ ] Double-click title bar to Toggle Maximize.
  - [ ] Click title bar to bring to front (already happens usually, but ensure consistency).
- [ ] **Window Decorations**:
  - [ ] Improve "Resize Handle" hit area (often too small).
  - [ ] Add consistent icons for Minimize/Maximize/Close buttons.

### System-Wide Visuals

- [ ] Ensure everything scales! Ensure everything fits their spaces. Nothing should be too big or too small.
- [ ] **Default Font**: Replace Godot default font with a clean Sans-Serif (e.g., Open Sans, Inter) for a non-gamey look.
- [ ] **Tooltip System**: Implement a global tooltip manager for Taskbar icons (`GameWindow` title on hover).

## 🟡 Medium Priority (Features & Polish)

### Standard App Library

- [ ] **Notepad Improvements**:
  - [ ] Switch `TextEdit` to `CodeEdit` or add line numbers.
  - [ ] Add a "File" menu (New, Open, Save As) using a standard dialog.
- [ ] **Settings App**:
  - [ ] Add a "Personalization" tab to pick Accent Colors (not just Light/Dark theme).
  - [ ] Add "About" section with OS version.
- [ ] **File Explorer (Missing)**: Create a basic file browser app to view `user://` content.

### Core Architecture

- [ ] **Dialog API**: Create a `DialogManager` autoload to spawn standard alerts/prompts.
  - [ ] `DialogManager.show_alert("Title", "Message")`
  - [ ] `DialogManager.show_confirm("Are you sure?", callback)`
- [ ] **Notification System**: Create a "Toast" notification overlay (bottom right) for logs/errors instead of just console prints.

## 🟢 Low Priority (Nice to Have)

### Advanced Windowing

- [ ] **Alt+Tab Switcher**: A visual overlay to switch focused windows via keyboard.
- [ ] **Window Animations**: specialized Tween animations for:
  - [ ] Opening (Scale up + Fade in).
  - [ ] Closing (Scale down + Fade out).
  - [ ] Minimizing (suck effect into taskbar?).

### Accessibility

- [ ] **UI Scaling**: Implement a global scale factor in Settings (1.0x, 1.25x, 1.5x) for high-DPI handling.
- [ ] **High Contrast Theme**: functional black/white theme.

### Developer Experience

- [ ] **Debug Console**: A quake-style dropdown terminal (`~` key) to run cheats/commands.
