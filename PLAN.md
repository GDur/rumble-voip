# Ideas and Plans


- [x] add the TWC server only when in the debug mode using the .env as the source.

- [x] **Versioning**: Implement a formal versioning system (starting at 0.1.0) and show it in the settings always at the bottom as a fine print for easy access.


- [x] make sure that the app (on android) does not stop or is going into sleep mode when in the background. maybe we can have an indicator that the app is still on somehow in a nice clean way

- [x] when on eg android then then top and bottom OS menus can lay over the sonner (toasts) which makes them unreadable. move them then so that they are still readable.

- [] add the possibility to add photos via a (+) file explorer too on all platfoms

- [x] make sure that users can post links and use links in their notice and that they are shown as clickable links. make sure that links are clickable on all platforms

- [] make it possible to load website previews (open graph) and urls eg for gifs, pdf's audio and video files

- [x] make sure that the new input gain is the same as the original one (atm the new clients are much quieter thant the old version. Other users have to use 10 to 16 db boost in the custom user volume settings)

- [ ] make the ptt buttons in the settings and the chatview about 70% seethrough (not in the standard view. only in the settings etc)

- [x] when the user joins a server then it will alsmost always write a custom welcome message. this should be shown as it contiains sometimes hints on how to behave etc. (its a text contained in the server info)

- [x] **Fix autojoin channel**: Check when the current channel is being saved. Also, rename "folder" to "channel" in the settings.

- [x] **Expand hotkey support**: Enable other actions to be triggered by hotkeys. Allow multiple hotkeys to activate a single action (e.g., F13 and Caps Lock could both trigger PTT).

- [x] **Filter empty channels**: Add a toggle button in the top header to hide empty channels in the view.

- [x] **Microphone permissions**: Request mic permissions immediately at app startup, as iOS seems to require an app restart after granting permissions. make sure that the ptt does not only work once. (as is now the case, make sure that we initialize the audio stuff once and then we one send it when we activate the ptt (if we try to initiate the audio. setup a second time it does not work anymore))

- [x] **Voice activity indicator**: When another user talks, do *not* make their label bold. Keep it normal.

- [x] **Channel tree refinements**:
    - [x] Add a hover effect to the channel tree.
    - [x] Indicate item selection on pointer down, not just on pointer up.
    - [x] Increase the hitbox size for the channel chevrons.
- [x] **Split Audio Settings**: Currently, Audio is one category. Split it into "Audio Input" and "Audio Output".

- [x] audio input delay settings: add delay so that it is easier that the hotkey tab sound is not being transmitted on laptop keyboards for example)

- [ ] **Verify hotkeys**:
    - [x] Ensure custom hotkeys work correctly (currently only selectable ones might work).
    - [ ] Ensure the "suppress hotkey" functionality works.
- [x] **Chat notifications**: Show the number of unread chat messages (on mobile/when the chat toggle is visible). Use a small number, or just a dot if more than 9. The indicator should disappear after the chat is opened/read.
- [ ] **Tooltips**: Add tooltips for almost all elements and buttons. (but not the ptt button!)
- [x] **Background support (Mobile)**: Allow the app to remain active in the background.
    - [] **Android**: Show a persistent indicator and/or a floating PTT button if possible.
    - [x] **General**: Show some kind of active status indicator.
- [x] **Certificate support**: Mumble can use certificates to identify users. (Implemented)
- [ ] **Voice Activity Detection (VAD)**:
    - [ ] Add auto-activation (VAD).
    - [ ] Add a slider to control VAD sensitivity.
- [ ] **Audio Transmission Options**:
    - [ ] Add an "Always Send" voice option.
    - [ ] Add a button to toggle between PTT, Always Send, and Auto-Activate.
- [ ] **Audio Processing**: Add echo cancellation.
- [ ] **User Controls**: Add mute and individual sound level controls for each user in the channel tree.
- [ ] **Resizable Chat**: Add a hidable chat pane on the right side using the [shadcn_ui Resizable](https://mariuti.com/flutter-shadcn-ui/components/resizable/) component.
    - [ ] Add support for private messaging (possibly with "pop-out" chat windows).
- [ ] **Floating Overlay (Mobile)**: Add a floating component that appears when connected to a server.
    - [ ] The component should show the PTT button and names of active speakers.
    - [ ] Enabled by default, but toggleable in settings.
    - [ ] Allow the component to be moved by dragging.
    - [ ] Allow the component to be hidden by tapping it.
    - [ ] Add a "maximize" button inside to return to the full app.