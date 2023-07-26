// gcc `allegro-config --cflags` `allegro-config --libs` -o test test.c

#include <allegro.h>
#include <stdio.h>

int main(int argc, char *argv[])
{
	install_allegro(SYSTEM_AUTODETECT, &errno, NULL);
	install_timer();
	install_mouse();
	install_keyboard();

	/* We are not 100% sure we can read the keyboard yet! */
	if (set_gfx_mode(GFX_AUTODETECT_WINDOWED, 640, 480, 0, 0) != 0) {
		printf("Couldn't set graphic mode!");
		return -1;
	}

	printf("Please press the key next to the 1\n");
	printf("Scancode for the key next to the 1 is according to allegro: %i\n", KEY_TILDE);
	while (1) {
		int scancode;
		int unicode = ureadkey(&scancode);
		printf("Scancode: %i (unicode: %i [%c])\n", scancode, unicode, (char)unicode);
	}
	return 0;
}