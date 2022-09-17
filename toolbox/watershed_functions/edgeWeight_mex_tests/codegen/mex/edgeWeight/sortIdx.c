/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * sortIdx.c
 *
 * Code generation for function 'sortIdx'
 *
 */

/* Include files */
#include "sortIdx.h"
#include "edgeWeight_data.h"
#include "edgeWeight_emxutil.h"
#include "edgeWeight_types.h"
#include "eml_int_forloop_overflow_check.h"
#include "rt_nonfinite.h"
#include "mwmathutil.h"

/* Variable Definitions */
static emlrtRSInfo v_emlrtRSI =
    {
        105,       /* lineNo */
        "sortIdx", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pathName */
};

static emlrtRSInfo w_emlrtRSI =
    {
        308,                /* lineNo */
        "block_merge_sort", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pathName */
};

static emlrtRSInfo x_emlrtRSI =
    {
        316,                /* lineNo */
        "block_merge_sort", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pathName */
};

static emlrtRSInfo y_emlrtRSI =
    {
        317,                /* lineNo */
        "block_merge_sort", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pathName */
};

static emlrtRSInfo ab_emlrtRSI =
    {
        325,                /* lineNo */
        "block_merge_sort", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pathName */
};

static emlrtRSInfo bb_emlrtRSI =
    {
        333,                /* lineNo */
        "block_merge_sort", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pathName */
};

static emlrtRSInfo cb_emlrtRSI =
    {
        392,                      /* lineNo */
        "initialize_vector_sort", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pathName */
};

static emlrtRSInfo db_emlrtRSI =
    {
        420,                      /* lineNo */
        "initialize_vector_sort", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pathName */
};

static emlrtRSInfo eb_emlrtRSI =
    {
        427,                      /* lineNo */
        "initialize_vector_sort", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pathName */
};

static emlrtRSInfo fb_emlrtRSI =
    {
        587,                /* lineNo */
        "merge_pow2_block", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pathName */
};

static emlrtRSInfo gb_emlrtRSI =
    {
        589,                /* lineNo */
        "merge_pow2_block", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pathName */
};

static emlrtRSInfo hb_emlrtRSI =
    {
        617,                /* lineNo */
        "merge_pow2_block", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pathName */
};

static emlrtRSInfo ib_emlrtRSI =
    {
        499,           /* lineNo */
        "merge_block", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pathName */
};

static emlrtRSInfo kb_emlrtRSI =
    {
        507,           /* lineNo */
        "merge_block", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pathName */
};

static emlrtRSInfo lb_emlrtRSI =
    {
        514,           /* lineNo */
        "merge_block", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pathName */
};

static emlrtRSInfo mb_emlrtRSI =
    {
        561,     /* lineNo */
        "merge", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pathName */
};

static emlrtRSInfo nb_emlrtRSI =
    {
        530,     /* lineNo */
        "merge", /* fcnName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pathName */
};

static emlrtRTEInfo q_emlrtRTEI =
    {
        61,        /* lineNo */
        5,         /* colNo */
        "sortIdx", /* fName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pName */
};

static emlrtRTEInfo r_emlrtRTEI =
    {
        386,       /* lineNo */
        1,         /* colNo */
        "sortIdx", /* fName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pName */
};

static emlrtRTEInfo s_emlrtRTEI =
    {
        388,       /* lineNo */
        1,         /* colNo */
        "sortIdx", /* fName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pName */
};

static emlrtRTEInfo t_emlrtRTEI =
    {
        308,       /* lineNo */
        14,        /* colNo */
        "sortIdx", /* fName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pName */
};

static emlrtRTEInfo u_emlrtRTEI =
    {
        308,       /* lineNo */
        20,        /* colNo */
        "sortIdx", /* fName */
        "/Applications/MATLAB_R2022a.app/toolbox/eml/eml/+coder/+internal/"
        "sortIdx.m" /* pName */
};

/* Function Declarations */
static void merge(const emlrtStack *sp, emxArray_int32_T *idx,
                  emxArray_real_T *x, int32_T offset, int32_T np, int32_T nq,
                  emxArray_int32_T *iwork, emxArray_real_T *xwork);

static void merge_block(const emlrtStack *sp, emxArray_int32_T *idx,
                        emxArray_real_T *x, int32_T offset, int32_T n,
                        int32_T preSortLevel, emxArray_int32_T *iwork,
                        emxArray_real_T *xwork);

/* Function Definitions */
static void merge(const emlrtStack *sp, emxArray_int32_T *idx,
                  emxArray_real_T *x, int32_T offset, int32_T np, int32_T nq,
                  emxArray_int32_T *iwork, emxArray_real_T *xwork)
{
  emlrtStack b_st;
  emlrtStack st;
  real_T *x_data;
  real_T *xwork_data;
  int32_T j;
  int32_T *idx_data;
  int32_T *iwork_data;
  st.prev = sp;
  st.tls = sp->tls;
  b_st.prev = &st;
  b_st.tls = st.tls;
  xwork_data = xwork->data;
  iwork_data = iwork->data;
  x_data = x->data;
  idx_data = idx->data;
  if (nq != 0) {
    int32_T iout;
    int32_T n_tmp;
    int32_T p;
    int32_T q;
    n_tmp = np + nq;
    st.site = &nb_emlrtRSI;
    if (n_tmp > 2147483646) {
      b_st.site = &j_emlrtRSI;
      check_forloop_overflow_error(&b_st);
    }
    for (j = 0; j < n_tmp; j++) {
      iout = offset + j;
      iwork_data[j] = idx_data[iout];
      xwork_data[j] = x_data[iout];
    }
    p = 0;
    q = np;
    iout = offset - 1;
    int32_T exitg1;
    do {
      exitg1 = 0;
      iout++;
      if (xwork_data[p] <= xwork_data[q]) {
        idx_data[iout] = iwork_data[p];
        x_data[iout] = xwork_data[p];
        if (p + 1 < np) {
          p++;
        } else {
          exitg1 = 1;
        }
      } else {
        idx_data[iout] = iwork_data[q];
        x_data[iout] = xwork_data[q];
        if (q + 1 < n_tmp) {
          q++;
        } else {
          q = iout - p;
          st.site = &mb_emlrtRSI;
          if ((p + 1 <= np) && (np > 2147483646)) {
            b_st.site = &j_emlrtRSI;
            check_forloop_overflow_error(&b_st);
          }
          for (j = p + 1; j <= np; j++) {
            iout = q + j;
            idx_data[iout] = iwork_data[j - 1];
            x_data[iout] = xwork_data[j - 1];
          }
          exitg1 = 1;
        }
      }
    } while (exitg1 == 0);
  }
}

static void merge_block(const emlrtStack *sp, emxArray_int32_T *idx,
                        emxArray_real_T *x, int32_T offset, int32_T n,
                        int32_T preSortLevel, emxArray_int32_T *iwork,
                        emxArray_real_T *xwork)
{
  emlrtStack st;
  int32_T bLen;
  int32_T nPairs;
  int32_T nTail;
  st.prev = sp;
  st.tls = sp->tls;
  nPairs = n >> preSortLevel;
  bLen = 1 << preSortLevel;
  while (nPairs > 1) {
    int32_T tailOffset;
    if ((nPairs & 1) != 0) {
      nPairs--;
      tailOffset = bLen * nPairs;
      nTail = n - tailOffset;
      if (nTail > bLen) {
        st.site = &ib_emlrtRSI;
        merge(&st, idx, x, offset + tailOffset, bLen, nTail - bLen, iwork,
              xwork);
      }
    }
    tailOffset = bLen << 1;
    nPairs >>= 1;
    for (nTail = 0; nTail < nPairs; nTail++) {
      st.site = &kb_emlrtRSI;
      merge(&st, idx, x, offset + nTail * tailOffset, bLen, bLen, iwork, xwork);
    }
    bLen = tailOffset;
  }
  if (n > bLen) {
    st.site = &lb_emlrtRSI;
    merge(&st, idx, x, offset, bLen, n - bLen, iwork, xwork);
  }
}

void sortIdx(const emlrtStack *sp, emxArray_real_T *x, emxArray_int32_T *idx)
{
  emlrtStack b_st;
  emlrtStack c_st;
  emlrtStack d_st;
  emlrtStack st;
  emxArray_int32_T *iwork;
  emxArray_real_T *xwork;
  real_T *x_data;
  real_T *xwork_data;
  int32_T b;
  int32_T b_b;
  int32_T ib;
  int32_T k;
  int32_T quartetOffset;
  int32_T *idx_data;
  int32_T *iwork_data;
  uint32_T unnamed_idx_0;
  int8_T perm[4];
  st.prev = sp;
  st.tls = sp->tls;
  b_st.prev = &st;
  b_st.tls = st.tls;
  c_st.prev = &b_st;
  c_st.tls = b_st.tls;
  d_st.prev = &c_st;
  d_st.tls = c_st.tls;
  x_data = x->data;
  emlrtHeapReferenceStackEnterFcnR2012b((emlrtCTX)sp);
  unnamed_idx_0 = (uint32_T)x->size[0];
  ib = idx->size[0];
  idx->size[0] = (int32_T)unnamed_idx_0;
  emxEnsureCapacity_int32_T(sp, idx, ib, &q_emlrtRTEI);
  idx_data = idx->data;
  quartetOffset = (int32_T)unnamed_idx_0;
  for (ib = 0; ib < quartetOffset; ib++) {
    idx_data[ib] = 0;
  }
  if (x->size[0] != 0) {
    real_T x4[4];
    int32_T idx4[4];
    int32_T bLen;
    int32_T b_n;
    int32_T i2;
    int32_T i3;
    int32_T i4;
    int32_T idx_tmp;
    int32_T n;
    int32_T nNonNaN;
    emxInit_int32_T(sp, &iwork, &t_emlrtRTEI);
    st.site = &v_emlrtRSI;
    n = x->size[0];
    b_st.site = &w_emlrtRSI;
    b_n = x->size[0];
    x4[0] = 0.0;
    idx4[0] = 0;
    x4[1] = 0.0;
    idx4[1] = 0;
    x4[2] = 0.0;
    idx4[2] = 0;
    x4[3] = 0.0;
    idx4[3] = 0;
    ib = iwork->size[0];
    iwork->size[0] = (int32_T)unnamed_idx_0;
    emxEnsureCapacity_int32_T(&b_st, iwork, ib, &r_emlrtRTEI);
    iwork_data = iwork->data;
    quartetOffset = (int32_T)unnamed_idx_0;
    for (ib = 0; ib < quartetOffset; ib++) {
      iwork_data[ib] = 0;
    }
    emxInit_real_T(&b_st, &xwork, &u_emlrtRTEI);
    quartetOffset = x->size[0];
    ib = xwork->size[0];
    xwork->size[0] = quartetOffset;
    emxEnsureCapacity_real_T(&b_st, xwork, ib, &s_emlrtRTEI);
    xwork_data = xwork->data;
    for (ib = 0; ib < quartetOffset; ib++) {
      xwork_data[ib] = 0.0;
    }
    bLen = 0;
    ib = -1;
    c_st.site = &cb_emlrtRSI;
    if (x->size[0] > 2147483646) {
      d_st.site = &j_emlrtRSI;
      check_forloop_overflow_error(&d_st);
    }
    for (k = 0; k < b_n; k++) {
      if (muDoubleScalarIsNaN(x_data[k])) {
        idx_tmp = (b_n - bLen) - 1;
        idx_data[idx_tmp] = k + 1;
        xwork_data[idx_tmp] = x_data[k];
        bLen++;
      } else {
        ib++;
        idx4[ib] = k + 1;
        x4[ib] = x_data[k];
        if (ib + 1 == 4) {
          real_T d;
          real_T d1;
          quartetOffset = k - bLen;
          if (x4[0] <= x4[1]) {
            ib = 1;
            i2 = 2;
          } else {
            ib = 2;
            i2 = 1;
          }
          if (x4[2] <= x4[3]) {
            i3 = 3;
            i4 = 4;
          } else {
            i3 = 4;
            i4 = 3;
          }
          d = x4[ib - 1];
          d1 = x4[i3 - 1];
          if (d <= d1) {
            d = x4[i2 - 1];
            if (d <= d1) {
              perm[0] = (int8_T)ib;
              perm[1] = (int8_T)i2;
              perm[2] = (int8_T)i3;
              perm[3] = (int8_T)i4;
            } else if (d <= x4[i4 - 1]) {
              perm[0] = (int8_T)ib;
              perm[1] = (int8_T)i3;
              perm[2] = (int8_T)i2;
              perm[3] = (int8_T)i4;
            } else {
              perm[0] = (int8_T)ib;
              perm[1] = (int8_T)i3;
              perm[2] = (int8_T)i4;
              perm[3] = (int8_T)i2;
            }
          } else {
            d1 = x4[i4 - 1];
            if (d <= d1) {
              if (x4[i2 - 1] <= d1) {
                perm[0] = (int8_T)i3;
                perm[1] = (int8_T)ib;
                perm[2] = (int8_T)i2;
                perm[3] = (int8_T)i4;
              } else {
                perm[0] = (int8_T)i3;
                perm[1] = (int8_T)ib;
                perm[2] = (int8_T)i4;
                perm[3] = (int8_T)i2;
              }
            } else {
              perm[0] = (int8_T)i3;
              perm[1] = (int8_T)i4;
              perm[2] = (int8_T)ib;
              perm[3] = (int8_T)i2;
            }
          }
          idx_data[quartetOffset - 3] = idx4[perm[0] - 1];
          idx_data[quartetOffset - 2] = idx4[perm[1] - 1];
          idx_data[quartetOffset - 1] = idx4[perm[2] - 1];
          idx_data[quartetOffset] = idx4[perm[3] - 1];
          x_data[quartetOffset - 3] = x4[perm[0] - 1];
          x_data[quartetOffset - 2] = x4[perm[1] - 1];
          x_data[quartetOffset - 1] = x4[perm[2] - 1];
          x_data[quartetOffset] = x4[perm[3] - 1];
          ib = -1;
        }
      }
    }
    i3 = (b_n - bLen) - 1;
    if (ib + 1 > 0) {
      perm[1] = 0;
      perm[2] = 0;
      perm[3] = 0;
      if (ib + 1 == 1) {
        perm[0] = 1;
      } else if (ib + 1 == 2) {
        if (x4[0] <= x4[1]) {
          perm[0] = 1;
          perm[1] = 2;
        } else {
          perm[0] = 2;
          perm[1] = 1;
        }
      } else if (x4[0] <= x4[1]) {
        if (x4[1] <= x4[2]) {
          perm[0] = 1;
          perm[1] = 2;
          perm[2] = 3;
        } else if (x4[0] <= x4[2]) {
          perm[0] = 1;
          perm[1] = 3;
          perm[2] = 2;
        } else {
          perm[0] = 3;
          perm[1] = 1;
          perm[2] = 2;
        }
      } else if (x4[0] <= x4[2]) {
        perm[0] = 2;
        perm[1] = 1;
        perm[2] = 3;
      } else if (x4[1] <= x4[2]) {
        perm[0] = 2;
        perm[1] = 3;
        perm[2] = 1;
      } else {
        perm[0] = 3;
        perm[1] = 2;
        perm[2] = 1;
      }
      c_st.site = &db_emlrtRSI;
      if (ib + 1 > 2147483646) {
        d_st.site = &j_emlrtRSI;
        check_forloop_overflow_error(&d_st);
      }
      for (k = 0; k <= ib; k++) {
        idx_tmp = perm[k] - 1;
        quartetOffset = (i3 - ib) + k;
        idx_data[quartetOffset] = idx4[idx_tmp];
        x_data[quartetOffset] = x4[idx_tmp];
      }
    }
    ib = (bLen >> 1) + 1;
    c_st.site = &eb_emlrtRSI;
    for (k = 0; k <= ib - 2; k++) {
      quartetOffset = (i3 + k) + 1;
      i2 = idx_data[quartetOffset];
      idx_tmp = (b_n - k) - 1;
      idx_data[quartetOffset] = idx_data[idx_tmp];
      idx_data[idx_tmp] = i2;
      x_data[quartetOffset] = xwork_data[idx_tmp];
      x_data[idx_tmp] = xwork_data[quartetOffset];
    }
    if ((bLen & 1) != 0) {
      ib += i3;
      x_data[ib] = xwork_data[ib];
    }
    nNonNaN = n - bLen;
    quartetOffset = 2;
    if (nNonNaN > 1) {
      if (n >= 256) {
        int32_T nBlocks;
        nBlocks = nNonNaN >> 8;
        if (nBlocks > 0) {
          b_st.site = &x_emlrtRSI;
          for (b = 0; b < nBlocks; b++) {
            real_T b_xwork[256];
            int32_T b_iwork[256];
            b_st.site = &y_emlrtRSI;
            i4 = (b << 8) - 1;
            for (b_b = 0; b_b < 6; b_b++) {
              bLen = 1 << (b_b + 2);
              b_n = bLen << 1;
              n = 256 >> (b_b + 3);
              c_st.site = &fb_emlrtRSI;
              for (k = 0; k < n; k++) {
                i2 = (i4 + k * b_n) + 1;
                c_st.site = &gb_emlrtRSI;
                for (quartetOffset = 0; quartetOffset < b_n; quartetOffset++) {
                  ib = i2 + quartetOffset;
                  b_iwork[quartetOffset] = idx_data[ib];
                  b_xwork[quartetOffset] = x_data[ib];
                }
                i3 = 0;
                quartetOffset = bLen;
                ib = i2 - 1;
                int32_T exitg1;
                do {
                  exitg1 = 0;
                  ib++;
                  if (b_xwork[i3] <= b_xwork[quartetOffset]) {
                    idx_data[ib] = b_iwork[i3];
                    x_data[ib] = b_xwork[i3];
                    if (i3 + 1 < bLen) {
                      i3++;
                    } else {
                      exitg1 = 1;
                    }
                  } else {
                    idx_data[ib] = b_iwork[quartetOffset];
                    x_data[ib] = b_xwork[quartetOffset];
                    if (quartetOffset + 1 < b_n) {
                      quartetOffset++;
                    } else {
                      ib -= i3;
                      c_st.site = &hb_emlrtRSI;
                      for (quartetOffset = i3 + 1; quartetOffset <= bLen;
                           quartetOffset++) {
                        idx_tmp = ib + quartetOffset;
                        idx_data[idx_tmp] = b_iwork[quartetOffset - 1];
                        x_data[idx_tmp] = b_xwork[quartetOffset - 1];
                      }
                      exitg1 = 1;
                    }
                  }
                } while (exitg1 == 0);
              }
            }
          }
          quartetOffset = nBlocks << 8;
          ib = nNonNaN - quartetOffset;
          if (ib > 0) {
            b_st.site = &ab_emlrtRSI;
            merge_block(&b_st, idx, x, quartetOffset, ib, 2, iwork, xwork);
          }
          quartetOffset = 8;
        }
      }
      b_st.site = &bb_emlrtRSI;
      merge_block(&b_st, idx, x, 0, nNonNaN, quartetOffset, iwork, xwork);
    }
    emxFree_real_T(&st, &xwork);
    emxFree_int32_T(&st, &iwork);
  }
  emlrtHeapReferenceStackLeaveFcnR2012b((emlrtCTX)sp);
}

/* End of code generation (sortIdx.c) */
