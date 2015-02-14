# TODO:
# - Maybe support negative length (like substr).
# - Get code review to see if char offset in IV is OK.
# - Maybe croak unless string/slice match on utf8-ness.
use strict;
package String::Slice;

our $VERSION = '0.08';

use Exporter 'import';
our @EXPORT = qw(slice);

use Config;
use Inline C => Config => ccflags => $Config::Config{ccflags} . " -Wall";

use String::Slice::Inline C => <<'...';
#ifndef CUSTOM_PP_OP
#define CUSTOM_PP_OP

static OP *custom_pp_op_checks(pTHX_ OP *o, GV *namegv, SV *ckobj)
{
	OP *parent, *pm, *first, *last;
	LISTOP *newop;
	STRLEN count;

	count = 0;
	parent = o;
	pm = cUNOPo->op_first;
	if (!pm->op_sibling) {
		parent = pm;
		pm = cUNOPx(parent)->op_first;
	}

	first = pm->op_sibling;

	if (first) {
		/* find the last arg in the chain */
		last = first;

		while (last && last->op_sibling) {
			count++;

			if (!last->op_sibling->op_sibling)
				break;

			last = last->op_sibling;
		}
	}

	/* No args */
	if (count == 0) {
		first = last = 0;
		count = 0;
	}

	/* Kill off parent tree */
	parent->op_next = NULL;
	cUNOPx(parent)->op_first = NULL;
	op_free(parent);

	/* Kill off dangling tree from last arg */
	if (last) {
		op_free(last->op_sibling);
		last->op_sibling = NULL;
	}

	/* generate new op tree */
	newop = newLISTOP(OP_CUSTOM, 0, 0, 0);
	newop->op_first = first;
	newop->op_last = last;
	newop->op_ppaddr = (void *)SvIV(ckobj);
	newop->op_private = count;
	newop->op_flags |= OPf_KIDS;
	newop->op_sibling = NULL;

	return newop;
}

void install_custom_pp_op(char *name, void *pp_addr)
{
	CV *sub;

	sub = get_cv(name, GV_ADD);

	if (!sub)
		croak("Unable to add subroutine %s\n", name);

	SV *ckobj = newSViv((IV)pp_addr);

	cv_set_call_checker(sub, custom_pp_op_checks, ckobj);

	return;
}

#endif

static OP *slice(pTHX) {
  dVAR; dSP; dTARGET;
  STRLEN items = PL_op->op_private;

  // Validate input:
  if (items < 2 || items > 4)
    croak("Usage: String::Slice::slice($slice, $string, $offset=0, $length=-1)");
  {
    STRLEN length = items < 4 ? -1 : POPl;
    I32 offset = items < 3 ? 0 : POPi;
    SV* string = POPs;
    SV* slice = POPs;

    if (! SvPOKp(slice))
      croak("String::Slice::slice '$slice' argument is not a string");
    if (! SvPOKp(string))
      croak("String::Slice::slice '$string' argument is not a string");

    // Set up local variables:
    U8* slice_ptr = SvPVX(slice);
    I32 slice_off;

    U8* string_ptr = SvPVX(string);
    U8* string_end = SvEND(string);

    U8* base_ptr;

    // Force string and slice to be string-type-scalars (SVt_PV):
#if PERL_VERSION > 18
    if(SvIsCOW(slice)) sv_force_normal(slice);
#endif


    // Is this a new slice? Start at beginning of string:
    if (slice_ptr < string_ptr || slice_ptr > string_end) {
      // Link the refcnt of string to slice:  (rafl++)
      sv_magicext(slice, string, PERL_MAGIC_ext, NULL, NULL, 0);

      // Special way to tell perl it doesn't own the slice memory:  (jdb++)
      SvLEN_set(slice, 0);

      // Make slice be utf8 if string is utf8:
      if (SvUTF8(string))
        SvUTF8_on(slice);

      // Make the SVs readonly:
      SvREADONLY_on(slice);
      SvREADONLY_on(string);

      base_ptr = string_ptr;
      slice_off = 0;
    }
    // Existing slice. Use it as starting point:
    else {
      base_ptr = slice_ptr;
      slice_off = SvIVX(slice);
    }

    if (SvUTF8(string)) {
      // Hop to the new offset:
      slice_ptr = utf8_hop(base_ptr, (offset - slice_off));
    } else {
      slice_ptr = base_ptr + (offset - slice_off);
    }

    // New offset is out of bounds. Handle failure:
    if (slice_ptr < string_ptr || slice_ptr > string_end) {
      // Reset the slice:
      SvPV_set(slice, 0);
      SvCUR_set(slice, 0);
      SvIVX(slice) = 0;
      // Failure:
      mXPUSHi(0);
      RETURN;
    }
    // New offset is OK. Handle success:
    else {
      // Set the slice pointer:
      SvPV_set(slice, slice_ptr);

      // Set the slice character offset (sneaky hack into IV slot):
      SvIVX(slice) = offset;

      // Calculate and set the proper byte length for the utf8 slice:

      if (length < 0) {
          SvCUR_set(slice, string_end - slice_ptr);
      }
      else if (SvUTF8(string)) {
        if (length >= utf8_distance(string_end, slice_ptr)) {
          SvCUR_set(slice, string_end - slice_ptr);
        }
        else
          SvCUR_set(slice, utf8_hop(slice_ptr, length) - slice_ptr);
      } else {
        if (length >= string_end - slice_ptr)
          SvCUR_set(slice, string_end - slice_ptr);
        else
          SvCUR_set(slice, length);
      }

      mXPUSHi(1);
      RETURN;
    }
  }
}

static XOP my_xop;

MODULE = String::Slice          PACKAGE = String::Slice

BOOT:
        XopENTRY_set(&my_xop, xop_name, "slice");
        XopENTRY_set(&my_xop, xop_desc, "Fake null");
        XopENTRY_set(&my_xop, xop_class, OA_LISTOP);
        Perl_custom_op_register(aTHX_ slice, &my_xop);

        install_custom_pp_op("String::Slice::slice", slice);

...

1;
