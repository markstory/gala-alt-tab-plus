# Gala Alt Tab Plus

Replace the default alt-tab behavior of gala/elementary os with a simpler UI
inspired by the Gnome switcher and MacOS.

![Example of application switcher](./example.png)


:warning: If you are looking for an Elementary 6 Odin compatible version check
out [small-tech/catts](https://github.com/small-tech/catts). :warning:

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

## Running tests

Modifying the primary gala instance can result in a broken desktop that requires a restart to fix.
To avoid this, you should use `xephyr`:

```bash
sudo apt install xserver-xephyr
# Run the test script starts up xephyr, calculator and xterm
./test.sh
```

With xephyr active you can give it focus with `ctrl-shift` and test out the new alt-tab behavior.

Once you're done testing you can remove the plugin with.

```bash
./cleanup.sh
```

## Troubleshooting

### Alt + Shift + Tab doesn't work

Elementary ships with `Alt + Shift` bound 'switch layouts'. Make sure you go
into 'Settings > Keyboard > Layout' and remove/reassign this keybinding.

## Tested versions

* Elementary OS 5.1.6
