# Snikket SDK

Working towards simplicity in developing Snikket-compatible apps.

    haxelib install datetime
    haxelib install haxe-strings
    haxelib install hsluv
    haxelib install tink_http
    haxelib install sha
    haxelib install thenshim
    make

# JavaScript

browser.js, though should also work on nodejs for the most part.
Also some typings are generated which include documenation comments.

# C

libsnikket.so and cpp/snikket.h, the latter has documentation comments

<details>
<summary><h2>Alpine Linux</h2></summary>

Build haxelib and neko from this aports branch:

https://gitlab.alpinelinux.org/alpine/aports/-/merge_requests/69597

Install the required make dependencies:

    doas apk add opus-dev libdatachannel-dev libstrophe-dev libc++-dev musl-dev --virtual snikket-sdk-makedeps

Building the sdk requires a `xlocale.h` file which is the same as the `locale.h` on your computer (provided by the `musl-dev` package).

    doas ln -s /usr/include/locale.h /usr/include/xlocale.h

Install the haxe dependencies and run make as above.
</details>

# Swift

libsnikket.so and cpp/snikket.h are wrapped by cpp/Snikket.swift
