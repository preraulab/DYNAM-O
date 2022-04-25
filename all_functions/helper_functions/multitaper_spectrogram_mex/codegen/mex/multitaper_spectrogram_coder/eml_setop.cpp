/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * eml_setop.cpp
 *
 * Code generation for function 'eml_setop'
 *
 */

/* Include files */
#include "eml_setop.h"
#include "issorted.h"
#include "multitaper_spectrogram_coder.h"
#include "multitaper_spectrogram_coder_emxutil.h"
#include "mwmathutil.h"
#include "rt_nonfinite.h"
#include <math.h>

/* Variable Definitions */
static emlrtRTEInfo s_emlrtRTEI = { 225,/* lineNo */
  13,                                  /* colNo */
  "do_vectors",                        /* fName */
  "/Applications/MATLAB_R2019b.app/toolbox/eml/lib/matlab/ops/private/eml_setop.m"/* pName */
};

static emlrtRTEInfo t_emlrtRTEI = { 228,/* lineNo */
  13,                                  /* colNo */
  "do_vectors",                        /* fName */
  "/Applications/MATLAB_R2019b.app/toolbox/eml/lib/matlab/ops/private/eml_setop.m"/* pName */
};

static emlrtRTEInfo u_emlrtRTEI = { 392,/* lineNo */
  5,                                   /* colNo */
  "do_vectors",                        /* fName */
  "/Applications/MATLAB_R2019b.app/toolbox/eml/lib/matlab/ops/private/eml_setop.m"/* pName */
};

static emlrtRTEInfo v_emlrtRTEI = { 430,/* lineNo */
  5,                                   /* colNo */
  "do_vectors",                        /* fName */
  "/Applications/MATLAB_R2019b.app/toolbox/eml/lib/matlab/ops/private/eml_setop.m"/* pName */
};

static emlrtRTEInfo je_emlrtRTEI = { 134,/* lineNo */
  22,                                  /* colNo */
  "eml_setop",                         /* fName */
  "/Applications/MATLAB_R2019b.app/toolbox/eml/lib/matlab/ops/private/eml_setop.m"/* pName */
};

static emlrtRTEInfo ke_emlrtRTEI = { 398,/* lineNo */
  9,                                   /* colNo */
  "eml_setop",                         /* fName */
  "/Applications/MATLAB_R2019b.app/toolbox/eml/lib/matlab/ops/private/eml_setop.m"/* pName */
};

static emlrtRTEInfo le_emlrtRTEI = { 434,/* lineNo */
  9,                                   /* colNo */
  "eml_setop",                         /* fName */
  "/Applications/MATLAB_R2019b.app/toolbox/eml/lib/matlab/ops/private/eml_setop.m"/* pName */
};

/* Function Declarations */
static real_T skip_to_last_equal_value(int32_T *k, const emxArray_real_T *x);

/* Function Definitions */
static real_T skip_to_last_equal_value(int32_T *k, const emxArray_real_T *x)
{
  real_T xk;
  boolean_T exitg1;
  real_T absx;
  int32_T exponent;
  boolean_T p;
  xk = x->data[*k - 1];
  exitg1 = false;
  while ((!exitg1) && (*k < x->size[1])) {
    absx = muDoubleScalarAbs(xk / 2.0);
    if ((!muDoubleScalarIsInf(absx)) && (!muDoubleScalarIsNaN(absx))) {
      if (absx <= 2.2250738585072014E-308) {
        absx = 4.94065645841247E-324;
      } else {
        frexp(absx, &exponent);
        absx = ldexp(1.0, exponent - 53);
      }
    } else {
      absx = rtNaN;
    }

    if ((muDoubleScalarAbs(xk - x->data[*k]) < absx) || (muDoubleScalarIsInf
         (x->data[*k]) && muDoubleScalarIsInf(xk) && ((x->data[*k] > 0.0) == (xk
           > 0.0)))) {
      p = true;
    } else {
      p = false;
    }

    if (p) {
      (*k)++;
    } else {
      exitg1 = true;
    }
  }

  return xk;
}

void do_vectors(const emlrtStack *sp, const emxArray_real_T *a, const
                emxArray_real_T *b, emxArray_real_T *c, emxArray_int32_T *ia,
                int32_T ib_size[1])
{
  int32_T na;
  int32_T iafirst;
  int32_T nc;
  int32_T nia;
  int32_T ialast;
  int32_T iblast;
  int32_T b_ialast;
  real_T ak;
  real_T bk;
  real_T absx;
  int32_T exponent;
  boolean_T p;
  na = a->size[1];
  iafirst = c->size[0] * c->size[1];
  c->size[0] = 1;
  c->size[1] = a->size[1];
  emxEnsureCapacity_real_T(sp, c, iafirst, &je_emlrtRTEI);
  iafirst = ia->size[0];
  ia->size[0] = a->size[1];
  emxEnsureCapacity_int32_T(sp, ia, iafirst, &je_emlrtRTEI);
  ib_size[0] = 0;
  if (!issorted(a)) {
    emlrtErrorWithMessageIdR2018a(sp, &s_emlrtRTEI,
      "Coder:toolbox:eml_setop_unsortedA", "Coder:toolbox:eml_setop_unsortedA",
      0);
  }

  if (!issorted(b)) {
    emlrtErrorWithMessageIdR2018a(sp, &t_emlrtRTEI,
      "Coder:toolbox:eml_setop_unsortedB", "Coder:toolbox:eml_setop_unsortedB",
      0);
  }

  nc = 0;
  nia = 0;
  iafirst = 0;
  ialast = 1;
  iblast = 1;
  while ((ialast <= na) && (iblast <= b->size[1])) {
    b_ialast = ialast;
    ak = skip_to_last_equal_value(&b_ialast, a);
    ialast = b_ialast;
    bk = skip_to_last_equal_value(&iblast, b);
    absx = muDoubleScalarAbs(bk / 2.0);
    if ((!muDoubleScalarIsInf(absx)) && (!muDoubleScalarIsNaN(absx))) {
      if (absx <= 2.2250738585072014E-308) {
        absx = 4.94065645841247E-324;
      } else {
        frexp(absx, &exponent);
        absx = ldexp(1.0, exponent - 53);
      }
    } else {
      absx = rtNaN;
    }

    if ((muDoubleScalarAbs(bk - ak) < absx) || (muDoubleScalarIsInf(ak) &&
         muDoubleScalarIsInf(bk) && ((ak > 0.0) == (bk > 0.0)))) {
      p = true;
    } else {
      p = false;
    }

    if (p) {
      ialast = b_ialast + 1;
      iafirst = b_ialast;
      iblast++;
    } else {
      if (muDoubleScalarIsNaN(bk)) {
        p = !muDoubleScalarIsNaN(ak);
      } else {
        p = ((!muDoubleScalarIsNaN(ak)) && (ak < bk));
      }

      if (p) {
        nc++;
        nia++;
        c->data[nc - 1] = ak;
        ia->data[nia - 1] = iafirst + 1;
        ialast = b_ialast + 1;
        iafirst = b_ialast;
      } else {
        iblast++;
      }
    }
  }

  while (ialast <= na) {
    iafirst = ialast;
    ak = skip_to_last_equal_value(&iafirst, a);
    nc++;
    nia++;
    c->data[nc - 1] = ak;
    ia->data[nia - 1] = ialast;
    ialast = iafirst + 1;
  }

  if (a->size[1] > 0) {
    if (nia > a->size[1]) {
      emlrtErrorWithMessageIdR2018a(sp, &u_emlrtRTEI,
        "Coder:builtins:AssertionFailed", "Coder:builtins:AssertionFailed", 0);
    }

    iafirst = ia->size[0];
    if (1 > nia) {
      ia->size[0] = 0;
    } else {
      ia->size[0] = nia;
    }

    emxEnsureCapacity_int32_T(sp, ia, iafirst, &ke_emlrtRTEI);
    if (nc > a->size[1]) {
      emlrtErrorWithMessageIdR2018a(sp, &v_emlrtRTEI,
        "Coder:builtins:AssertionFailed", "Coder:builtins:AssertionFailed", 0);
    }

    iafirst = c->size[0] * c->size[1];
    if (1 > nc) {
      c->size[1] = 0;
    } else {
      c->size[1] = nc;
    }

    emxEnsureCapacity_real_T(sp, c, iafirst, &le_emlrtRTEI);
  }
}

/* End of code generation (eml_setop.cpp) */
