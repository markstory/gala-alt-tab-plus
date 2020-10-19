# Gala Alt Tab Plus

Replace the default alt-tab behavior of gala/elementary os with a simpler UI
inspired by the Gnome switcher and MacOS.

![](./example.png)

This is based off of [tom95/gala-alternate-alt-tab](https://github.com/tom95/gala-alternate-alt-tab)

## Build Requirements

* elementary-sdk
* libclutter-1.0-dev
* libwnck-3-dev

Make sure you `apt install` all of the above requirements before trying to build.

## Install

build from sources:

```bash
mkdir build
cd build
cmake ..
make
sudo make install

# Restart gala
sudo gala --replace &
```

## Troubleshooting

### Alt + Shift + Tab doesn't work

Elementary ships with `Alt + Shift` bound 'switch layouts'. Make sure you go
into 'Settings > Keyboard > Layout' and remove/reassign this keybinding.

## Tested versions

* Elementary OS 5.1.6
