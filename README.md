# Rumble

**Rumble** is an alternative Mumble voice chat client built with [Flutter](https://flutter.dev), designed to bring a modern UI/UX to the rock-solid Mumble protocol.

The goal is to create a seamless experience across all platforms—Mobile, Tablet, and Desktop—without sacrificing the performance Mumble is known for.

## Why Rumble?

- **Modern UI/UX**: A fresh, high-quality interface that doesn't feel like it's from the early 2000s.
- **Cross-Platform**: Built to work everywhere. One codebase, one experience.
- **Interoperable**: Rumble works in tandem with original Mumble clients. You can switch to Rumble without forcing your friends or community to change anything.
- **AI-Assisted Development**: This project is developed by a human programmer with significant assistance from AI to speed up boilerplate and implementation.

## Project Status

Rumble is currently in active development.


## Platform Support Matrix

| Platform | Works | Does not work |
| :--- | :---: | :---: |
| Android | x | |
| iOS (Tablet and iPhones)| x |  |
| macOS (Apple Silicon and Intel) | x | |
| Windows | (x)* | |
| Linux | (x)* | |
| Web (can't work) | | x |

\* *Requires native `libopus` libraries in the application directory.*


### Currently Supported
- **Mobile/Tablets**: Full voice functionality with hotkey/PTT support.
- **Desktop (macOS, Linux, Windows)**: Global hotkey activation (Push-to-Talk) is functional across all three desktop platforms.

### Planned for the Future
- **Auto-Updates**: Seamless versioning so you're always on the latest build.
- **Advanced Audio Controls**: More granular control over your voice experience.
- **Premium Themes**: Further polish on the already modern design.

## Tech Stack
- **Framework**: Flutter
- **UI System**: shadcn_ui (Flutter implementation)
- **Protocol**: Mumble (via dumble)
- **State Management**: Provider

## Branding
If you update `assets/icon.png`, you can regenerate all app icons and splash screens for all platforms by running:
```bash
./scripts/update_branding.sh
```

## Disclaimer & No Warranty

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

---

*Developed with ❤️ and 🤖*
