/* $Id$ */

/** @file Geometry functions */

#include "../stdafx.h"
#include "math_func.hpp"
#include "geometry_func.h"

/** Return smallest dimension large enough to hold both arguments */
Dimension max(const Dimension& d1, const Dimension& d2)
{
	return MakeDimension(max(d1.width, d2.width), max(d1.height, d2.height));
}
