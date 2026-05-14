PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
PLISTDIR = $(HOME)/Library/LaunchAgents

.PHONY: build install uninstall clean dmg app

build:
	swift build -c release

install: build
	install -d $(BINDIR)
	install .build/release/nonsleep $(BINDIR)/nonsleep
	install .build/release/nonsleepd $(BINDIR)/nonsleepd
	install -d $(PLISTDIR)
	install -m 644 scripts/com.nonsleep.daemon.plist $(PLISTDIR)/com.nonsleep.daemon.plist
	launchctl load $(PLISTDIR)/com.nonsleep.daemon.plist 2>/dev/null || true

uninstall:
	-launchctl unload $(PLISTDIR)/com.nonsleep.daemon.plist 2>/dev/null
	rm -f $(BINDIR)/nonsleep $(BINDIR)/nonsleepd
	rm -f $(PLISTDIR)/com.nonsleep.daemon.plist
	rm -rf $(HOME)/Library/Application\ Support/NonSleep

app: build
	@scripts/build-dmg.sh

dmg: app

clean:
	swift package clean
	rm -rf .build dist
