# mobile-game-template

`flib` のシーンベース構成で、スマホ向け縦持ち 16:9 (720x1280) の最小テンプレートです。

## Included

- 画像ロード: `game/assets/images`
- フォントロード: `game/assets/fonts`
- SE/BGMロード: `game/assets/se`, `game/assets/bgm`
- JSONロード: `game/assets/data`

## Run

```bash
go run .
```

## Build all

```bash
go build ./...
```

## Mobile binding

```bash
ebitenmobile bind -v -target ios -o ./ios/Mobile.xcframework ./mobile
# or
# ebitenmobile bind -v -target android -javapkg com.example.mobilegametemplate -o ./android/mobile-game-template.aar ./mobile
```
