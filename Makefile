HOST              := darwin-x86_64
ANDROID_API_LEVEL := 31
ANDROID_ABI       := arm64-v8a
TOOLCHAIN_DIR     := $(ANDROID_NDK_ROOT)/toolchains/llvm/prebuilt/$(HOST)
TARGET_TRIPLE     := aarch64-linux-android
CC                := $(TOOLCHAIN_DIR)/bin/clang
CMAKE_ARGS        := -DCMAKE_TOOLCHAIN_FILE=$(ANDROID_NDK_ROOT)/build/cmake/android.toolchain.cmake -DANDROID_ABI=$(ANDROID_ABI) -DANDROID_PLATFORM=android-$(ANDROID_API_LEVEL)

CRYSTAL         ?= crystal
CRYSTAL_SRC_DIR := app/src/main/crystal
JNI_LIBS_DIR    := app/src/main/jniLibs/$(ANDROID_ABI)
STATIC_LIBS_DIR := etc/$(ANDROID_ABI)

SRCS := $(abspath $(CRYSTAL_SRC_DIR)/hello_world.cr)
LIBS := -llog -landroid -lgc -lm -levent -lEGL -lGLESv3
O    := $(abspath $(CRYSTAL_SRC_DIR)/hello_world)
SO   := $(JNI_LIBS_DIR)/libnative-activity.so
APK  := app/build/outputs/apk/debug/app-debug.apk

.PHONY: all install uninstall clean deps $(APK) $(SO) $O.o
.SUFFIXES:

all: apk

apk: $(APK)

$(APK): $(SO)
	./gradlew assembleDebug

$(SO): $O.o deps
	$(CC) "--target=$(TARGET_TRIPLE)$(ANDROID_API_LEVEL)" $(LIBS) -L "etc/$(ANDROID_ABI)" -shared -u ANativeActivity_onCreate -o "$(SO)" "$O.o"

$O.o:
	cd "$(CRYSTAL_SRC_DIR)" > /dev/null && \
		shards && \
		ANDROID_PLATFORM=$(ANDROID_API_LEVEL) $(CRYSTAL) build -Duse_pcre2 --cross-compile "--target=$(TARGET_TRIPLE)" -o "$O" $(SRCS) > /dev/null

deps: $(STATIC_LIBS_DIR)/libgc.a $(STATIC_LIBS_DIR)/libpcre2-8.a $(STATIC_LIBS_DIR)/libevent.a

$(STATIC_LIBS_DIR)/libgc.a:
	git clone -b v8.2.2 https://github.com/ivmai/bdwgc.git bdwgc
	git clone -b v7.6.14 https://github.com/ivmai/libatomic_ops.git bdwgc/libatomic_ops
	cd bdwgc && \
		cmake . $(CMAKE_ARGS) -DBUILD_SHARED_LIBS=OFF && \
		cmake --build . --config Release
	mv bdwgc/libgc.a "$(STATIC_LIBS_DIR)"
	rm -rf bdwgc

$(STATIC_LIBS_DIR)/libpcre2-8.a:
	git clone -b pcre2-10.42 https://github.com/PCRE2Project/pcre2.git pcre2
	cd pcre2 && \
		cmake . $(CMAKE_ARGS) -DBUILD_SHARED_LIBS=OFF -DPCRE2_BUILD_PCRE2GREP=OFF -DPCRE2_BUILD_TESTS=OFF -DPCRE2_SUPPORT_UNICODE=ON -DPCRE2_SUPPORT_JIT=ON && \
		cmake --build . --config Release
	mv pcre2/libpcre2-8.a "$(STATIC_LIBS_DIR)"
	rm -rf pcre2

# TODO: enable OpenSSL
# FIXME: latest libevent release fails to build on Android
$(STATIC_LIBS_DIR)/libevent.a:
	git clone https://github.com/libevent/libevent.git libevent
	cd libevent && \
		git checkout 8f47d8de281b877450474734594fdc0a60ee35d1 && \
		cmake . $(CMAKE_ARGS) -DEVENT__LIBRARY_TYPE=STATIC -DEVENT__DISABLE_OPENSSL=ON -DEVENT__DISABLE_MBEDTLS=ON -DEVENT__DISABLE_BENCHMARK=ON -DEVENT__DISABLE_TESTS=ON -DEVENT__DISABLE_REGRESS=ON -DEVENT__DISABLE_SAMPLES=ON && \
		cmake --build . --config Release
	mv libevent/lib/libevent.a "$(STATIC_LIBS_DIR)"
	rm -rf libevent

install:
	./gradlew installDebug

uninstall:
	./gradlew uninstallDebug

clean:
	./gradlew clean
	rm "$(STATIC_LIBS_DIR)/libgc.a" "$(STATIC_LIBS_DIR)/libpcre2-8.a" "$(STATIC_LIBS_DIR)/libevent.a"
	rm "$(SO)"
	rm "$O.o"
