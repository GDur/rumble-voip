# Ideas and Plans


- [] add the TWC server only when in the debug mode using the .env as the source.

- [ ] **Versioning**: Implement a formal versioning system (starting at 0.1.0) and reflect it in the "About" section of the settings.


- [] make sure that the app (on android) does not stop or is going into sleep mode when in the background

 - [] when on eg android then then top and bottom OS menus can lay over the sonner (toasts) which makes them unreadable. move them then so that they are still readable.

- [] add the possibility to add photos via a (+) file explorer too on all platfoms

- [x] make sure that users can post links and use links in their notice and that they are shown as clickable links. make sure that links are clickable on all platforms

- [] make it possible to load website previews (open graph) and urls eg for gifs, pdf's audio and video files

- [x] make sure that the new input gain is the same as the original one (atm the new clients are much quieter thant the old version. Other users have to use 10 to 16 db boost in the custom user volume settings)


- [ ] when the user joins a server then it will alsmost always write a custom welcome message. this should be shown as it contiains sometimes hints on how to behave etc.

- [ ] **Fix autojoin channel**: Check when the current channel is being saved. Also, rename "folder" to "channel" in the settings.
- [ ] **Expand hotkey support**: Enable other actions to be triggered by hotkeys. Allow multiple hotkeys to activate a single action (e.g., F13 and Caps Lock could both trigger PTT).
- [ ] **Filter empty channels**: Add a toggle to hide empty channels in the view.
- [ ] **Microphone permissions**: Request mic permissions immediately at app startup, as iOS seems to require an app restart after granting permissions.
- [ ] **Voice activity indicator**: When another user talks, do *not* make their label bold. Keep it normal.
- [ ] **Channel tree refinements**:
    - [ ] Add a hover effect to the channel tree.
    - [ ] Indicate item selection on pointer down, not just on pointer up.
    - [ ] Increase the hitbox size for the channel chevrons.
- [ ] **Split Audio Settings**: Currently, Audio is one category. Split it into "Audio Input" and "Audio Output".
- [ ] **Verify hotkeys**:
    - [ ] Ensure custom hotkeys work correctly (currently only selectable ones might work).
    - [ ] Ensure the "suppress hotkey" functionality works.
- [ ] **Chat notifications**: Show the number of unread chat messages (on mobile/when the chat toggle is visible). Use a small number, or just a dot if more than 9. The indicator should disappear after the chat is opened/read.
- [ ] **Tooltips**: Add tooltips for almost all elements and buttons.
- [ ] **Background support (Mobile)**: Allow the app to remain active in the background.
    - [ ] **Android**: Show a persistent indicator and/or a floating PTT button if possible.
    - [ ] **General**: Show some kind of active status indicator.
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