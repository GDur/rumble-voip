# Ideas and Plans to tackle next

[] fix autojoin channel: check when current channel is being safed. Also rename in settings from folder to channel
[] make it so that other actions can also be triggered by hotkeys. And that multiple hotkeys can activate one action. Eg F13 and Capslock could both trigger ptt.
[] add a filter toggle which hides empty channels in the view
[] make it so that the permission for mic question comes directly at the start of the program because it seems like iOs needs a reboot of the app after granting the permission
[] when another user talks _don't_ make their label bold. leave it normal as is.
[] the channel tree needs a hover effect. And selecting an item should be indicated on pointer down not just on pointer up. 
  [] the hitbox for the channel chevrons needs to be bigger
[] Atm the Settings Audio is one category. Its better to split it into  Audio Input and Audio Output
[] Versioning: the app should follow a real versioning system probably starting at 0.1.0 Whcih should also always be reflected in the settings about section.
[] make sure that custom hotkeys really work (maybe atm just the selectable ones work)
[] make sure that the "suppress hotkey" is really working
[] show how many chat notifications are there, if there are any (on mobile/when the toggle chat button is visible). small number and if more than 9 then maybe just a dot. disappears when messages have been read(after chat was opened)
[] add tooltips for almost al elements/buttons etc
[] make it possible on mobile to leave the app open in the background
    - android: show some kind of indicator and or maybe a floating ptt button if possile too
    - show some kind of indicator

[x] mumble can usse certificates to identify users. lets add support for that.

[] add auto activation (voice activity detection)
    [] add a slider to control the sensitivity of the auto activation
[] add always send voice option
[] add a button to toggle between ptt and always send voice or auto activate
[] add echo cancellation
[] add mute + sound level for each user in the channel tree
[] add the chat on the right side (make it hidable and use the https://mariuti.com/flutter-shadcn-ui/components/resizable/ component to resize it)
    [] add the possibility to chat with specific persons (maybe even pop out to own chat windows) 

[] on mobile, lets try add a floating component on the screen when the user is connected to a server, eg to show the ptt button and maybe the names of the people currently talking.
is then turned on as default but can be turned off in the settings.
    [] on mobile, the floating component should be able to be moved around the screen by dragging it.
    [] on mobile, the floating component should be able to be hidden by tapping on it.
    [] on mobile, the floating component should be able to be expanded to see the hole app again by tapping a max button inside.