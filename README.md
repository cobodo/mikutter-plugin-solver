# mikutter-plugin-solver
mikutterプラグインの依存関係をどうにかするやつ

## 使い方
### git gemのインストール
```console-shell
$ gem install git
```

### 環境変数
- `MIKUTTER_ROOT`: mikutter本体のパス。デフォルトは `/usr/share/mikutter` 。
- `MIKUTTER_CONFROOT`: `.mikutter` のパス。デフォルトは `$HOME/.mikutter` 。

### 例
```console-shell
$ cd ~
$ git clone git://mikutter.hachune.net/mikutter.git mikutter
$ cd mikutter
$ git switch develop
$ cd ~
$ git clone https://github.com/cobodo/mikutter-plugin-solver
$ mkdir -p ~/.mikutter-itsumono/plugin
$ cd ~/.mikutter-itsumono/plugin
$ git clone https://github.com/cobodo/itsumonoyatsu
$ MIKUTTER_ROOT=~/mikutter MIKUTTER_CONFROOT=~/.mikutter-itsumono ~/mikutter-plugin-solver/mps
```

## 依存関係記述仕様
TODO: 書く

