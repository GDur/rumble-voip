#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

HHOOK FlutterWindow::keyboard_hook_ = nullptr;
HWND FlutterWindow::s_window_handle_ = nullptr;
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> FlutterWindow::permissions_channel_ = nullptr;
int FlutterWindow::ptt_vk_code_ = 0;
bool FlutterWindow::ptt_suppress_ = false;

LRESULT CALLBACK FlutterWindow::KeyboardHookProc(int nCode, WPARAM wParam, LPARAM lParam) {
  if (nCode == HC_ACTION) {
    KBDLLHOOKSTRUCT* kbStruct = (KBDLLHOOKSTRUCT*)lParam;
    if (ptt_vk_code_ != 0 && kbStruct->vkCode == ptt_vk_code_) {
      if (permissions_channel_) {
        bool isDown = (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN);
        bool isUp = (wParam == WM_KEYUP || wParam == WM_SYSKEYUP);
        
        if (isDown || isUp) {
          flutter::EncodableMap args = {
            {flutter::EncodableValue("event"), flutter::EncodableValue(isDown ? "down" : "up")},
            {flutter::EncodableValue("vkCode"), flutter::EncodableValue((int)kbStruct->vkCode)}
          };
          permissions_channel_->InvokeMethod("onNativeKey", std::make_unique<flutter::EncodableValue>(args));
          
          if (ptt_suppress_) {
            return 1; // Suppress key
          }
        }
      }
    }
  }
  return CallNextHookEx(keyboard_hook_, nCode, wParam, lParam);
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  s_window_handle_ = GetHandle();
  permissions_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.rumble.app/permissions",
      &flutter::StandardMethodCodec::GetInstance());

  permissions_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name().compare("setPttVkCode") == 0) {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto it = arguments->find(flutter::EncodableValue("vkCode"));
            if (it != arguments->end()) {
              FlutterWindow::ptt_vk_code_ = std::get<int>(it->second);
            }
            auto it_suppress = arguments->find(flutter::EncodableValue("suppress"));
            if (it_suppress != arguments->end()) {
              FlutterWindow::ptt_suppress_ = std::get<bool>(it_suppress->second);
            }
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  keyboard_hook_ = SetWindowsHookEx(WH_KEYBOARD_LL, KeyboardHookProc, GetModuleHandle(NULL), 0);

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (keyboard_hook_) {
    UnhookWindowsHookEx(keyboard_hook_);
    keyboard_hook_ = nullptr;
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
