module libmicrohttpd.cslice;

extern (C) struct c_slice
{
    /*actuallly immutable*/ const uint element_size;
    
    void* ptr;
    uint length;
    
    /// currently used size
    uint size;
    /// currently unused size
    uint capacity;
    
    void* past_last_element;
}

void append(c_slice* slice, void* thingy,
    const char* file = __FILE__.ptr, uint line = __LINE__)
{
    while (slice.capacity < slice.element_size)
    {
        grow(slice);
        if (!slice.ptr)
        {
            import core.stdc.stdio : stderr, fprintf;
            fprintf(stderr, "OOM while growing array at %s::%d\n", file, line);
            import core.stdc.stdlib : abort;
            abort();
        }
    }
    import core.stdc.string : memcpy;

    memcpy(slice.past_last_element, thingy, slice.element_size);
    slice.past_last_element += slice.element_size;
    slice.length += 1;
    slice.size += slice.element_size;
    slice.capacity -= slice.element_size;
    
}

/// Params:
///     element_size = size of an array element
extern(C) c_slice allocate(immutable uint element_size, uint size = 1024)
{
    import core.stdc.stdlib : malloc;
    auto mem = malloc(size);
    return c_slice(element_size, mem, 0, 0, size, mem);
}
/// grows the slice by size specified in bytes
/// you must check the return value for null!
extern (C) void* grow(c_slice* slice, uint grow_by = 256)
{
    import core.stdc.stdlib : realloc;
    slice.capacity += grow_by;
    slice.ptr = realloc(slice.ptr, slice.size + grow_by);
    
    slice.past_last_element = slice.ptr + (slice.element_size * slice.length);
    
    return slice.ptr;
}

extern(C) void deallocate(c_slice* slice)
{
    import core.stdc.stdlib : free;
    free(slice.ptr);
    (cast(void*)(slice))[0 .. c_slice.sizeof] = (cast(void*)&c_slice_init)[0 .. c_slice.sizeof];
}

/// resets the slice without deallocating it
extern(C) void reset(c_slice* slice)
{
    slice.ptr -= slice.size;
    slice.past_last_element = slice.ptr;
    slice.length = 0;
    slice.capacity += slice.size;
    slice.size = 0;
}
static immutable c_slice c_slice_init = c_slice.init;