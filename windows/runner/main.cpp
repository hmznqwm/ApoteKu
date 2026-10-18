#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>
#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // Determine monitor DPI scale factor to convert physical screen bounds to logical coordinates
  POINT target_point = {10, 10};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = (dpi > 0) ? (dpi / 96.0) : 1.0;

  RECT work_area;
  SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0);
  int work_width_phys = work_area.right - work_area.left;
  int work_height_phys = work_area.bottom - work_area.top;

  int work_width_log = static_cast<int>(work_width_phys / scale_factor);
  int work_height_log = static_cast<int>(work_height_phys / scale_factor);

  int window_width = (std::min)(1280, (std::max)(600, work_width_log - 32));
  int window_height = (std::min)(720, (std::max)(400, work_height_log - 40));
  int x = (work_width_log - window_width) / 2;
  int y = (work_height_log - window_height) / 2;

  FlutterWindow window(project);
  Win32Window::Point origin(x, y);
  Win32Window::Size size(window_width, window_height);
  if (!window.Create(L"ApoteKu", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}

