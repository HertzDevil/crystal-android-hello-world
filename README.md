## crystal-android-hello-world

Example of building a native Android app using pure Crystal, which shows the
spinning icosahedron from the [Crystal website](https://crystal-lang.org/)
recreated in OpenGL ES, using
[android-ndk.cr](https://github.com/HertzDevil/android-ndk.cr)

1. Install the Android NDK
2. Prepare a Crystal compiler with Android support from
   [this branch](https://github.com/HertzDevil/crystal/tree/test/termux)
3. Run `CRYSTAL=<bin/crystal from above> make`
4. If an Android device or emulator is available, run `make install`
