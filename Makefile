
##
## kiosk + presence -- install only
##
## kiosk:          cage + cog showing KIOSK_URL full screen on tty1, as the kiosk user
## kiosk-presence: webcam motion sensor that switches the kiosk's screen off and on
##

SCRIPT=kiosk-presence

all: check

check: $(SCRIPT)
	node --check $(SCRIPT)
	@echo "syntax OK"

.PHONY: all check

##

PACKAGES=cage cog wlr-randr v4l-utils curl nodejs
install-deps:
	apt-get install -y --no-install-recommends $(PACKAGES)
.PHONY: install-deps

##

KIOSK_USER=kiosk
DIR_LIB=/usr/local/lib/kiosk-presence
DIR_DEFAULT=/etc/default
DIR_SYSTEMD=/etc/systemd/system
HOSTNAME:=$(shell hostname)
# a per-host config wins when there is one: kiosk.<hostname>.cfg, kiosk-presence.<hostname>.cfg
pick=$(if $(wildcard $(1).$(HOSTNAME).cfg),$(1).$(HOSTNAME).cfg,$(1).cfg)

# video for the camera, render/input for the compositor
install-user:
	@id $(KIOSK_USER) >/dev/null 2>&1 || { \
	  useradd --system --create-home --home-dir /var/lib/$(KIOSK_USER) --shell /usr/sbin/nologin \
	    --groups video,render,input $(KIOSK_USER) && echo "created user $(KIOSK_USER)"; }
	@usermod -aG video,render,input $(KIOSK_USER)

install-files: $(SCRIPT) kiosk.service kiosk-presence.service
	install -d $(DIR_LIB)
	install -m 755 $(SCRIPT) $(DIR_LIB)/$(SCRIPT)
	@echo "installing config from $(call pick,kiosk) and $(call pick,kiosk-presence)"
	install -m 644 $(call pick,kiosk) $(DIR_DEFAULT)/kiosk
	install -m 644 $(call pick,kiosk-presence) $(DIR_DEFAULT)/kiosk-presence
	install -m 644 kiosk.service $(DIR_SYSTEMD)/kiosk.service
	install -m 644 kiosk-presence.service $(DIR_SYSTEMD)/kiosk-presence.service

# kiosk is restarted too: on a box still running the older cog-on-DRM unit, that is the switch to cage
install-services:
	systemctl daemon-reload
	systemctl enable kiosk kiosk-presence
	systemctl restart kiosk
	systemctl restart kiosk-presence

install: check install-deps install-user install-files install-services
	@echo "installed -- check with: make status"

restart:
	systemctl restart kiosk kiosk-presence

status:
	@systemctl --no-pager --lines=0 status kiosk kiosk-presence || true
	@journalctl -u kiosk-presence -n 6 --no-pager -o short

# what would change: repo copy against what is installed
diff:
	-@diff -u $(DIR_LIB)/$(SCRIPT) $(SCRIPT)
	-@diff -u $(DIR_DEFAULT)/kiosk $(call pick,kiosk)
	-@diff -u $(DIR_DEFAULT)/kiosk-presence $(call pick,kiosk-presence)
	-@diff -u $(DIR_SYSTEMD)/kiosk.service kiosk.service
	-@diff -u $(DIR_SYSTEMD)/kiosk-presence.service kiosk-presence.service

# presence only: the kiosk itself stays (stopping the sensor turns the screen back on)
uninstall:
	-systemctl stop kiosk-presence
	-systemctl disable kiosk-presence
	rm -f $(DIR_SYSTEMD)/kiosk-presence.service
	rm -rf $(DIR_LIB)
	systemctl daemon-reload
	@echo "left in place: $(DIR_DEFAULT)/kiosk-presence, the kiosk service and its user"

.PHONY: install install-user install-files install-services restart status diff uninstall

##
