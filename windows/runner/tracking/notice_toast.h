#ifndef WITRACK_NOTICE_TOAST_H_
#define WITRACK_NOTICE_TOAST_H_

#include <string>

namespace witrack {

/// Topmost tool-window toast at the bottom-right of the work area.
/// Separate HWND from the main Flutter window. Auto-closes; click ✕ to dismiss.
void ShowDesktopNoticeToastUtf8(const std::string& title,
                                const std::string& body,
                                const std::string& kind,
                                int duration_ms);

}  // namespace witrack

#endif  // WITRACK_NOTICE_TOAST_H_
