# Hangtag

A tiny native macOS app that hangs every screenshot on a line at the top of your screen.

Take a screenshot and it drops onto the line. Rest the pointer in the menu bar to bring the line down, then drag a photo into any app, click it to copy, or press and hold to mark it up. When you are done, take one down with its cross or clear the whole line at once.

[繁體中文說明](#繁體中文)

## Features

- **Screenshots hang instantly.** Hangtag can take over where macOS saves screenshots, so they skip the Desktop and the floating thumbnail. Your previous settings come back when you turn it off or quit.
- **Bring the line down from the menu bar** on any display, with or without a menu bar, in a window or over full screen apps. A keyboard shortcut works too.
- **Drag a photo anywhere.** An app gets a copy, a folder keeps the file, the Trash discards it.
- **Copy new screenshots automatically**, ready to paste with ⌘V. Images copied in other apps are left on the clipboard as they are.
- **Take everything down** with one button at the end of the line.
- **Mark up** a screenshot with press and hold. Edits are saved in the original format and size.
- **Hang copied images** and images saved to folders you choose.
- **Light in the background**: about 0.5% CPU and 35 MB of memory while the line is tucked away.
- Interface in English, 繁體中文, 简体中文, Español, Français, Português, 日本語, 한국어, Türkçe, Azərbaycan, Galego and हिन्दी.

## Requirements

macOS 14 Sonoma or later, on Apple silicon or Intel.

## Build

No Xcode project needed, only the Swift toolchain (Xcode or the Command Line Tools).

```bash
scripts/build-app.sh
```

The app is written to `build/Hangtag.app`. Move it to `/Applications` and open it. Without a Developer ID it is signed ad hoc, so macOS asks again for folder access after each new build.

`scripts/make-dmg.sh` packs a release disk image, and `swift scripts/check-strings.swift` checks the translations.

## Troubleshooting

Hangtag logs why the line did not come down when you expected it to:

```bash
log show --last 1h --predicate 'subsystem == "io.github.anderson930420.Hangtag"'
```

## License

MIT. See [LICENSE](LICENSE).

---

## 繁體中文

一個輕巧的 macOS 原生 App：每張截圖都會掛在螢幕頂端的一條繩子上。

截圖後它會自動掛上繩子。把滑鼠停在選單列，繩子就會放下來：把照片拖進任何 App、點一下拷貝，或按住不放進行標示。用完了，按照片左上角的叉叉取下一張，或一鍵清空整條繩子。

- **截圖立刻掛上**：可以接管 macOS 的截圖存放位置，不再堆在桌面，也不會出現浮動縮圖。關閉或結束時會還原你原本的設定。
- **從選單列叫出繩子**：任何螢幕都適用，有沒有選單列、視窗或全螢幕都可以，也可以用快速鍵。
- **拖到哪裡都行**：拖進 App 是拷貝一份，拖進資料夾就保留檔案，拖到垃圾桶就丟掉。
- **自動拷貝新截圖**：截完直接 ⌘V。從其他 App 拷貝的圖片不會被覆蓋。
- **一鍵全部取下**：繩子右端的按鈕。
- **標示**：按住照片即可編輯，存回時維持原本的格式與大小。
- **背景很省**：繩子收起時約 0.5% CPU、35 MB 記憶體。

需要 macOS 14 以上。用 `scripts/build-app.sh` 建置，產生的 App 在 `build/Hangtag.app`。
