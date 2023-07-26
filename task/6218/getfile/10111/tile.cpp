#include <cstdio>

typedef unsigned char byte;
typedef unsigned short uint16;

struct Tile {
  byte type; ///< The type (bits 4..7), bridges (2..3), rainforest/desert (0..1)
  byte height; ///< The height of the northern corner.
  byte m1; ///< Primarily used for ownership information
  uint16 m2; ///< Primarily used for indices to towns, industries and stations
  byte m3; ///< General purpose
  byte m4; ///< General purpose
  byte m5; ///< General purpose
};

struct Tile2 {
  byte type; ///< The type (bits 4..7), bridges (2..3), rainforest/desert (0..1)
  byte height; ///< The height of the northern corner.
  uint16 m2; ///< Primarily used for indices to towns, industries and stations
  byte m1; ///< Primarily used for ownership information
  byte m3; ///< General purpose
  byte m4; ///< General purpose
  byte m5; ///< General purpose
};

int main() {
  printf("sizeof(Tile) == %ld\n", sizeof(Tile));
  printf("sizeof(Tile2) == %ld\n", sizeof(Tile2));
  return 0;
}
