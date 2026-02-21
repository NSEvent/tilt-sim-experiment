SHELL := /bin/sh

.PHONY: build run clean

build:
	swift build -c release

run: build
	sudo .build/release/TiltSim

run-no-tilt: build
	.build/release/TiltSim

clean:
	swift package clean
