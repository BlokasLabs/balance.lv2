#!/usr/bin/make -f

# these can be overrideen using make variables. e.g.
#   make CFLAGS=-O2
#   make install DESTDIR=$(CURDIR)/debian/balance_lv2 PREFIX=/usr
#
OPTIMIZATIONS ?= -msse -msse2 -mfpmath=sse -ffast-math -fomit-frame-pointer -O3 -fno-finite-math-only
PREFIX ?= /usr/local
CFLAGS ?= $(OPTIMIZATIONS) -Wall
LIBDIR ?= lib

###############################################################################

LV2DIR ?= $(PREFIX)/$(LIBDIR)/lv2
LOADLIBES=-lm
LV2NAME=balance
LV2GUI=balanceUI
BUNDLE=balance.lv2
CFLAGS+=-fPIC -std=c99
TX=textures/

IS_OSX=
UNAME=$(shell uname)
ifeq ($(UNAME),Darwin)
  IS_OSX=yes
  LV2LDFLAGS=-dynamiclib
  LIB_EXT=.dylib
else
  CFLAGS+= -DHAVE_MEMSTREAM
  LV2LDFLAGS=-Wl,-Bstatic -Wl,-Bdynamic
  LIB_EXT=.so
endif

targets=$(LV2NAME)$(LIB_EXT)

# check for build-dependencies
ifeq ($(shell pkg-config --exists lv2 lv2core || echo no), no)
  $(error "LV2 SDK was not found")
else
  CFLAGS+=`pkg-config --cflags lv2 lv2core`
endif

# optional UI
ifeq ($(IS_OSX), yes)
  FONTFILE?=/usr/X11/lib/X11/fonts/TTF/VeraBd.ttf
else
  FONTFILE?=/usr/share/fonts/truetype/ttf-bitstream-vera/VeraBd.ttf
endif

ifeq ($(shell test -f $(FONTFILE) || echo no ), no)
  $(warning UI font can not be found on this system, install bitstream-vera TTF or set the FONTFILE variable to a ttf file)
  $(warning LV2 GUI will not be built)
  FONT_FOUND=no
else
  FONT_FOUND=yes
endif

ifeq ($(IS_OSX), yes)
  HAVE_UI=$(shell pkg-config --exists ftgl && echo $(FONT_FOUND))
else
  HAVE_UI=$(shell pkg-config --exists glu ftgl && echo $(FONT_FOUND))
endif

LV2UIREQ=
# check for LV2 idle thread -- requires 'lv2', atleast_version='1.4.1
ifeq ($(shell pkg-config --atleast-version=1.4.2 lv2 || echo no), no)
  CFLAGS+=-DOLD_SUIL
else
  LV2UIREQ=lv2:requiredFeature ui:idle;\\n\\tlv2:extensionData ui:idle;
endif

ifeq ($(HAVE_UI), yes)
  UIDEPS=pugl/pugl.h pugl/pugl_internal.h ui_model.h
  UIDEPS+=$(TX)dial.c $(TX)background.c
  ifeq ($(IS_OSX), yes)
    UIDEPS+=pugl/pugl_osx.m
    UILIBS=pugl/pugl_osx.m -framework Cocoa -framework OpenGL
    UI_TYPE=CocoaUI
  else
    UIDEPS+=pugl/pugl_x11.c
    CFLAGS+=`pkg-config --cflags glu`
    UILIBS=pugl/pugl_x11.c -lX11 `pkg-config --libs glu`
    UI_TYPE=X11UI
  endif
  CFLAGS+=`pkg-config --cflags ftgl`
  UILIBS+=`pkg-config --libs ftgl`
  CFLAGS+=-DFONTFILE=\"$(FONTFILE)\"
  targets+=$(LV2GUI)$(LIB_EXT)
else
  $(warning "openGL/GLU is not available - install glu-dev to include LV2 GUI")
endif


# build target definitions
default: all

all: manifest.ttl $(LV2NAME).ttl $(targets)

manifest.ttl: manifest.ttl.in manifest.ui.ttl.in
	sed "s/@LV2NAME@/$(LV2NAME)/;s/@LIB_EXT@/$(LIB_EXT)/" \
	  manifest.ttl.in > manifest.ttl
ifeq ($(HAVE_UI), yes)
	sed "s/@LV2NAME@/$(LV2NAME)/;s/@LV2GUI@/$(LV2GUI)/;s/@LIB_EXT@/$(LIB_EXT)/;s/@UI_TYPE@/$(UI_TYPE)/" manifest.ui.ttl.in >> manifest.ttl
endif

$(LV2NAME).ttl: $(LV2NAME).ttl.in $(LV2NAME).ui.ttl.in
	cat $(LV2NAME).ttl.in > $(LV2NAME).ttl
ifeq ($(HAVE_UI), yes)
	sed "s/@UI_TYPE@/$(UI_TYPE)/;s/@UI_REQ@/$(LV2UIREQ)/;" $(LV2NAME).ui.ttl.in >> $(LV2NAME).ttl
endif

$(LV2NAME)$(LIB_EXT): balance.c uris.h
	$(CC) $(CFLAGS) \
	  -o $(LV2NAME)$(LIB_EXT) balance.c \
	  $(LDFLAGS) $(LOADLIBES) -shared $(LV2LDFLAGS)

$(LV2GUI)$(LIB_EXT): ui.c uris.h $(UIDEPS)
	$(CC) $(CFLAGS) \
		-o $(LV2GUI)$(LIB_EXT) ui.c \
		$(LDFLAGS) $(UICFLAGS) $(UILIBS) -shared $(LV2LDFLAGS)

# install/uninstall/clean target definitions

install: all
	install -d $(DESTDIR)$(LV2DIR)/$(BUNDLE)
	install -m755 $(LV2NAME)$(LIB_EXT) $(DESTDIR)$(LV2DIR)/$(BUNDLE)
	install -m644 manifest.ttl $(LV2NAME).ttl $(DESTDIR)$(LV2DIR)/$(BUNDLE)
ifeq ($(HAVE_UI), yes)
	install -m755 $(LV2GUI)$(LIB_EXT) $(DESTDIR)$(LV2DIR)/$(BUNDLE)
endif

uninstall:
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/*.ttl
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/$(LV2NAME)$(LIB_EXT)
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/$(LV2GUI)$(LIB_EXT)
	-rmdir $(DESTDIR)$(LV2DIR)/$(BUNDLE)

clean:
	rm -f *.o manifest.ttl $(LV2NAME)$(LIB_EXT) $(LV2GUI)$(LIB_EXT)

.PHONY: clean all install uninstall
