SHELL := /bin/sh

.PHONY: build run clean

build:
	swift build -c release

run: build
	.build/release/TiltSim

clean:
	swift package clean
