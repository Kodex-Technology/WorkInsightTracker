#ifndef RUNNER_WINDOW_PLACEMENT_H_
#define RUNNER_WINDOW_PLACEMENT_H_

#include <windows.h>

// Physical-pixel window bounds persisted under HKCU\Software\Witrack\Window.
struct PersistedWindowBounds {
  int x = 0;
  int y = 0;
  int width = 0;
  int height = 0;
  bool maximized = false;
};

bool LoadPersistedWindowBounds(PersistedWindowBounds* out);
void PersistWindowBounds(HWND window);
bool ApplyPersistedWindowBounds(HWND window, const PersistedWindowBounds& bounds);

#endif  // RUNNER_WINDOW_PLACEMENT_H_
