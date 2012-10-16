#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdio.h>

MODULE = String::Slice  PACKAGE = String::Slice  PREFIX = StringSlice_

PROTOTYPES: DISABLE

int
StringSlice_slice (slice, string, offset = 0, length = -1)
    SV* slice;
    SV* string;
    I32 offset;
    STRLEN length;
INIT:
    U8* slice_ptr;
    U8* slice_end;
    U8* string_ptr;
    U8* string_end;
    U8* base_ptr;
CODE:
    // Force string and slice to be string-type-scalars (SVt_PV)
    SvUPGRADE(slice, SVt_PV);
    SvUPGRADE(string, SVt_PV);

    // Make sure string is a valid string pointer
    if (! SvPOK(string))
        croak("buffer is not a string in String::Slice::slice()");

    // Get current pointers and string length
    slice_ptr = SvPVX(slice);
    string_ptr = SvPVX(string);
    string_end = SvEND(string);

    // Is this a new slice? Start at beginning of string.
    if (slice_ptr < string_ptr || slice_ptr >= string_end) {
        // Link the refcnt of string to slice. rafl++
        sv_magicext(slice, string, PERL_MAGIC_ext, NULL, NULL, 0);

        base_ptr = string_ptr;
    }
    // Existing slice. Use it as starting point.
    else {
        base_ptr = slice_ptr;
    }

    // Hop to the new offset
    slice_ptr = utf8_hop(base_ptr, offset);

    // New offset is out of bounds
    if (slice_ptr < string_ptr || slice_ptr >= string_end) {
        // Reset the slice
        SvPV_set(slice, 0);
        SvCUR_set(slice, 0);

        // Failure RETVAL
        RETVAL = 0;
    }
    // New offset is OK.
    else {
        // Set the slice pointer.
        SvPV_set(slice, slice_ptr);

        // Calculate the proper byte length for the utf8 slice

        // If requested number of chars is negative (default) or too big,
        // use the entire remainder of the string.
        if (length < 0 || length >= utf8_distance(string_end, slice_ptr)) {
            slice_end = string_end;
        }
        // Else find the end of utf8 slice
        else {
            slice_end = utf8_hop(slice_ptr, length);
        }
        // Set the length of the slice buffer in bytes
        SvCUR_set(slice, slice_end - slice_ptr);

        // Special way to tell perl it doesn't own the slice memory. jdb++
        SvLEN_set(slice, 0);

        // Make sure the SVs are readonly (or bad things will happen!)
        SvREADONLY_on(slice);
        SvREADONLY_on(string);

        // Success RETVAL
        RETVAL = 1;
    }
OUTPUT:
    RETVAL
