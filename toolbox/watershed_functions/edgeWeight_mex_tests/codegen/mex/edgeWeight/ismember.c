/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * ismember.c
 *
 * Code generation for function 'ismember'
 *
 */

/* Include files */
#include "ismember.h"
#include "edgeWeight_data.h"
#include "edgeWeight_emxutil.h"
#include "edgeWeight_types.h"
#include "eml_int_forloop_overflow_check.h"
#include "rt_nonfinite.h"
#include "sort.h"
#include "mwmathutil.h"
#include "omp.h"

/* Variable Definitions */
static emlrtRSInfo
    d_emlrtRSI =
        {
            162,        /* lineNo */
            "isMember", /* fcnName */
            "/Applications/MATLAB_R2022a.app/toolbox/eml/lib/matlab/ops/"
            "ismember.m" /* pathName */
};

static emlrtRSInfo
    e_emlrtRSI =
        {
            163,        /* lineNo */
            "isMember", /* fcnName */
            "/Applications/MATLAB_R2022a.app/toolbox/eml/lib/matlab/ops/"
            "ismember.m" /* pathName */
};

static emlrtRSInfo
    f_emlrtRSI =
        {
            173,        /* lineNo */
            "isMember", /* fcnName */
            "/Applications/MATLAB_R2022a.app/toolbox/eml/lib/matlab/ops/"
            "ismember.m" /* pathName */
};

static emlrtRSInfo
    g_emlrtRSI =
        {
            180,        /* lineNo */
            "isMember", /* fcnName */
            "/Applications/MATLAB_R2022a.app/toolbox/eml/lib/matlab/ops/"
            "ismember.m" /* pathName */
};

static emlrtRSInfo
    h_emlrtRSI =
        {
            183,        /* lineNo */
            "isMember", /* fcnName */
            "/Applications/MATLAB_R2022a.app/toolbox/eml/lib/matlab/ops/"
            "ismember.m" /* pathName */
};

static emlrtRSInfo
    i_emlrtRSI =
        {
            202,        /* lineNo */
            "isMember", /* fcnName */
            "/Applications/MATLAB_R2022a.app/toolbox/eml/lib/matlab/ops/"
            "ismember.m" /* pathName */
};

static emlrtRSInfo
    n_emlrtRSI =
        {
            27,     /* lineNo */
            "sort", /* fcnName */
            "/Applications/MATLAB_R2022a.app/toolbox/eml/lib/matlab/datafun/"
            "sort.m" /* pathName */
};

static emlrtRTEInfo
    h_emlrtRTEI =
        {
            120,        /* lineNo */
            1,          /* colNo */
            "ismember", /* fName */
            "/Applications/MATLAB_R2022a.app/toolbox/eml/lib/matlab/ops/"
            "ismember.m" /* pName */
};

static emlrtRTEInfo
    i_emlrtRTEI =
        {
            27,     /* lineNo */
            6,      /* colNo */
            "sort", /* fName */
            "/Applications/MATLAB_R2022a.app/toolbox/eml/lib/matlab/datafun/"
            "sort.m" /* pName */
};

static emlrtRTEInfo
    j_emlrtRTEI =
        {
            129,        /* lineNo */
            10,         /* colNo */
            "ismember", /* fName */
            "/Applications/MATLAB_R2022a.app/toolbox/eml/lib/matlab/ops/"
            "ismember.m" /* pName */
};

static emlrtRTEInfo
    k_emlrtRTEI =
        {
            115,        /* lineNo */
            21,         /* colNo */
            "ismember", /* fName */
            "/Applications/MATLAB_R2022a.app/toolbox/eml/lib/matlab/ops/"
            "ismember.m" /* pName */
};

/* Function Declarations */
static int32_T bsearchni(int32_T k, const emxArray_real_T *x,
                         const emxArray_real_T *s);

/* Function Definitions */
static int32_T bsearchni(int32_T k, const emxArray_real_T *x,
                         const emxArray_real_T *s)
{
  const real_T *s_data;
  const real_T *x_data;
  real_T b_x;
  int32_T idx;
  int32_T ihi;
  int32_T ilo;
  boolean_T exitg1;
  s_data = s->data;
  x_data = x->data;
  b_x = x_data[k - 1];
  ihi = s->size[0];
  idx = 0;
  ilo = 1;
  exitg1 = false;
  while ((!exitg1) && (ihi >= ilo)) {
    int32_T imid;
    imid = ((ilo >> 1) + (ihi >> 1)) - 1;
    if (((ilo & 1) == 1) && ((ihi & 1) == 1)) {
      imid++;
    }
    if (b_x == s_data[imid]) {
      idx = imid + 1;
      exitg1 = true;
    } else {
      boolean_T p;
      if (muDoubleScalarIsNaN(s_data[imid])) {
        p = !muDoubleScalarIsNaN(b_x);
      } else if (muDoubleScalarIsNaN(b_x)) {
        p = false;
      } else {
        p = (b_x < s_data[imid]);
      }
      if (p) {
        ihi = imid;
      } else {
        ilo = imid + 2;
      }
    }
  }
  if (idx > 0) {
    idx--;
    while ((idx > 0) && (b_x == s_data[idx - 1])) {
      idx--;
    }
    idx++;
  }
  return idx;
}

void isMember(const emlrtStack *sp, const emxArray_real_T *a,
              const emxArray_real_T *s, emxArray_boolean_T *tf)
{
  jmp_buf *volatile emlrtJBStack;
  emlrtStack b_st;
  emlrtStack st;
  emxArray_int32_T *ec_emlrtRSI;
  emxArray_real_T *ss;
  const real_T *a_data;
  const real_T *s_data;
  real_T *ss_data;
  int32_T k;
  int32_T n;
  int32_T na;
  int32_T ns;
  int32_T pmax;
  int32_T pmin;
  boolean_T exitg1;
  boolean_T guard1 = false;
  boolean_T *tf_data;
  st.prev = sp;
  st.tls = sp->tls;
  b_st.prev = &st;
  b_st.tls = st.tls;
  s_data = s->data;
  a_data = a->data;
  emlrtHeapReferenceStackEnterFcnR2012b((emlrtCTX)sp);
  na = a->size[0];
  ns = s->size[0];
  pmin = tf->size[0];
  tf->size[0] = a->size[0];
  emxEnsureCapacity_boolean_T(sp, tf, pmin, &h_emlrtRTEI);
  tf_data = tf->data;
  pmax = a->size[0];
  for (pmin = 0; pmin < pmax; pmin++) {
    tf_data[pmin] = false;
  }
  emxInit_real_T(sp, &ss, &j_emlrtRTEI);
  emxInit_int32_T(sp, &ec_emlrtRSI, &k_emlrtRTEI);
  guard1 = false;
  if (s->size[0] <= 4) {
    guard1 = true;
  } else {
    pmax = 31;
    pmin = 0;
    exitg1 = false;
    while ((!exitg1) && (pmax - pmin > 1)) {
      int32_T p;
      int32_T pow2p;
      p = (pmin + pmax) >> 1;
      pow2p = 1 << p;
      if (pow2p == ns) {
        pmax = p;
        exitg1 = true;
      } else if (pow2p > ns) {
        pmax = p;
      } else {
        pmin = p;
      }
    }
    if (a->size[0] <= pmax + 4) {
      guard1 = true;
    } else {
      boolean_T y;
      st.site = &f_emlrtRSI;
      y = true;
      pmax = 0;
      exitg1 = false;
      while ((!exitg1) && (pmax <= s->size[0] - 2)) {
        real_T d;
        d = s_data[pmax + 1];
        if ((s_data[pmax] <= d) || muDoubleScalarIsNaN(d)) {
          pmax++;
        } else {
          y = false;
          exitg1 = true;
        }
      }
      if (!y) {
        st.site = &g_emlrtRSI;
        pmin = ss->size[0];
        ss->size[0] = s->size[0];
        emxEnsureCapacity_real_T(&st, ss, pmin, &i_emlrtRTEI);
        ss_data = ss->data;
        pmax = s->size[0];
        for (pmin = 0; pmin < pmax; pmin++) {
          ss_data[pmin] = s_data[pmin];
        }
        b_st.site = &n_emlrtRSI;
        sort(&b_st, ss, ec_emlrtRSI);
        st.site = &h_emlrtRSI;
        if (a->size[0] > 2147483646) {
          b_st.site = &j_emlrtRSI;
          check_forloop_overflow_error(&b_st);
        }
        pmax = a->size[0] - 1;
        emlrtEnterParallelRegion((emlrtCTX)sp, omp_in_parallel());
        emlrtPushJmpBuf((emlrtCTX)sp, &emlrtJBStack);
#pragma omp parallel for num_threads(                                          \
    emlrtAllocRegionTLSs(sp->tls, omp_in_parallel(), omp_get_max_threads(),    \
                         omp_get_num_procs())) private(n)

        for (k = 0; k <= pmax; k++) {
          n = bsearchni(k + 1, a, ss);
          if (n > 0) {
            tf_data[k] = true;
          }
        }
        emlrtPopJmpBuf((emlrtCTX)sp, &emlrtJBStack);
        emlrtExitParallelRegion((emlrtCTX)sp, omp_in_parallel());
      } else {
        st.site = &i_emlrtRSI;
        if (a->size[0] > 2147483646) {
          b_st.site = &j_emlrtRSI;
          check_forloop_overflow_error(&b_st);
        }
        pmax = a->size[0] - 1;
        emlrtEnterParallelRegion((emlrtCTX)sp, omp_in_parallel());
        emlrtPushJmpBuf((emlrtCTX)sp, &emlrtJBStack);
#pragma omp parallel for num_threads(                                          \
    emlrtAllocRegionTLSs(sp->tls, omp_in_parallel(), omp_get_max_threads(),    \
                         omp_get_num_procs())) private(n)

        for (k = 0; k <= pmax; k++) {
          n = bsearchni(k + 1, a, s);
          if (n > 0) {
            tf_data[k] = true;
          }
        }
        emlrtPopJmpBuf((emlrtCTX)sp, &emlrtJBStack);
        emlrtExitParallelRegion((emlrtCTX)sp, omp_in_parallel());
      }
    }
  }
  if (guard1) {
    st.site = &d_emlrtRSI;
    if (a->size[0] > 2147483646) {
      b_st.site = &j_emlrtRSI;
      check_forloop_overflow_error(&b_st);
    }
    for (pmin = 0; pmin < na; pmin++) {
      st.site = &e_emlrtRSI;
      if (ns > 2147483646) {
        b_st.site = &j_emlrtRSI;
        check_forloop_overflow_error(&b_st);
      }
      pmax = 0;
      exitg1 = false;
      while ((!exitg1) && (pmax <= ns - 1)) {
        if (a_data[pmin] == s_data[pmax]) {
          tf_data[pmin] = true;
          exitg1 = true;
        } else {
          pmax++;
        }
      }
    }
  }
  emxFree_int32_T(sp, &ec_emlrtRSI);
  emxFree_real_T(sp, &ss);
  emlrtHeapReferenceStackLeaveFcnR2012b((emlrtCTX)sp);
}

/* End of code generation (ismember.c) */
