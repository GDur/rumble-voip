enum HotkeyAction {
  pushToTalk('Push-To-Talk'),
  toggleMute('Toggle Mute'),
  toggleDeafen('Toggle Deafen'),
  toggleSpeakerMute('Toggle Speaker Mute');

  final String label;
  const HotkeyAction(this.label);

  static HotkeyAction fromName(String name) {
    return HotkeyAction.values.firstWhere(
      (e) => e.name == name,
      orElse: () => HotkeyAction.pushToTalk,
    );
  }
}
