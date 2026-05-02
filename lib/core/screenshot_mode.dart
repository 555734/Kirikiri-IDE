const bool _kCompileTimeDemo = bool.fromEnvironment('SCREENSHOT_MODE');
bool _runtimeDemoMode = false;

bool get kDemoMode => _kCompileTimeDemo || _runtimeDemoMode;

void enableRuntimeDemoMode() {
  _runtimeDemoMode = true;
}
