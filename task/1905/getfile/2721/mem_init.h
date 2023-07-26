/* $Id$ */

/** @file mem_init.h
 * Base class that allocates memory, and initializes it to 0 prior to applying the constructor
 * Also, memory is released after exit of the destructor
 *
 * @note This provides only partial safety; local variables are never allocated at the heap.
 */

#ifndef MEM_INIT_H
#define MEM_INIT_H

/**
 * Base class that provides memory initialization on dynamically created objects.
 */
class MemInitialize
{
public:
	MemInitialize();
	virtual ~MemInitialize();

	void *operator new(size_t size);
	void *operator new[](size_t size);
	void operator delete(void *ptr, size_t size);
	void operator delete[](void *ptr, size_t size);
};

/**
 * Constructor
 */
inline MemInitialize::MemInitialize()
{
}

/**
 * Destructor
 */
inline MemInitialize::~MemInitialize()
{
}

/**
 * Memory allocator for single class instance
 */
inline void *MemInitialize::operator new(size_t size)
{
	void *ptr = malloc(size);
	memset(ptr, 0, size);
	return ptr;
}

/**
 * Memory allocator for array of class instances
 */
inline void *MemInitialize::operator new[](size_t size)
{
	void *ptr = malloc(size);
	memset(ptr, 0, size);
	return ptr;
}

/**
 * Memory release for single class instance
 */
inline void MemInitialize::operator delete(void *ptr, size_t size)
{
	free(ptr);
}


/**
 * Memory release for array of class instances
 */
inline void MemInitialize::operator delete[](void *ptr, size_t size)
{
	free(ptr);
}

#endif
