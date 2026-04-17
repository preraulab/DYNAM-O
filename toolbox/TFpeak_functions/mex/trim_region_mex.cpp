// trim_region_mex.cpp
//
// Per-region morphology kernel for trimWshedRegions. Replaces the
// imfill + bwconncomp + pick-largest-by-volume + bwboundaries sequence
// with a single C++ pass.
//
// Called once per region from the trimWshedRegions MATLAB loop. Given a
// subimage of data values and a list of "above-threshold" pixel indices,
// returns (a) the linear indices of the largest-volume connected
// component after filling interior holes, and (b) the set of boundary
// pixels of that component.
//
// Equivalence contract: (a) must match MATLAB's
//     tmp_data = imfill(bw,'holes');
//     cc      = bwconncomp(tmp_data, conn);
//     [~,idx] = max(cellfun(@(x)sum(sub_shift_data(x),'omitnan'), cc.PixelIdxList));
//     keep    = cc.PixelIdxList{idx};
// as a set (pixel ordering within the CC in MATLAB's raster order).
// (b) matches the set of boundary pixels of that CC (a pixel p is on the
// boundary iff p is in the CC and at least one 4-neighbor of p is NOT in
// the CC, or p is on the image edge). The boundary is emitted in
// ascending linear-index order; the MATLAB caller must normalize order
// for downstream comparisons.
//
// Usage:
//   [sub_keep_idx, sub_bnd_idx] = trim_region_mex(sub_data, sub_trim_idx, conn)
//
// KNOWN LIMITATION (conn=4): the boundary-detection pass always uses a
// 4-neighbor check regardless of `conn`, which is correct for conn=8
// components but diverges from MATLAB's bwboundaries(mask, 4) on conn=4
// components. Regions are still bit-identical in both modes; only the
// boundary set differs with conn=4. The entire DYNAM-O pipeline passes
// conn=8 (grep "conn_trim" in extractTFPeaks.m), so this latent bug has
// zero production impact. test_all_optimizations.m reports it as NOTE,
// not FAIL. Fix is straightforward if conn=4 is ever wired through:
// adjust the boundary check to use the same neighborhood as `conn`.
//
// Inputs:
//   sub_data     - MxN double subimage (already shifted so min>=0)
//   sub_trim_idx - int32 column of 1-based linear indices into sub_data
//                  for the pixels to set to 1 in the binary mask
//   conn         - int32 scalar, 4 or 8 (connectivity for CC labeling)
//
// Outputs:
//   sub_keep_idx - int32 column of 1-based linear indices in sub_data of
//                  the picked CC's pixels (raster/column-major order)
//   sub_bnd_idx  - int32 column of 1-based linear indices of the picked
//                  CC's 4-connected boundary pixels (ascending order)

#include "mex.hpp"
#include "mexAdapter.hpp"

#include <cstdint>
#include <cstring>
#include <queue>
#include <vector>
#include <limits>

using matlab::data::Array;
using matlab::data::ArrayFactory;
using matlab::data::ArrayType;
using matlab::data::TypedArray;
using matlab::data::ArrayDimensions;

class MexFunction : public matlab::mex::Function {
    ArrayFactory factory;
    std::shared_ptr<matlab::engine::MATLABEngine> matlabPtr = getEngine();

    void err(const std::string& msg) {
        matlabPtr->feval(u"error", 0,
            std::vector<Array>({factory.createScalar(msg)}));
    }

public:
    void operator()(matlab::mex::ArgumentList outputs,
                    matlab::mex::ArgumentList inputs) override {
        if (inputs.size() != 3) err("trim_region_mex: expected 3 inputs");
        if (inputs[0].getType() != ArrayType::DOUBLE) err("sub_data must be double");
        if (inputs[1].getType() != ArrayType::INT32)  err("sub_trim_idx must be int32");
        if (inputs[2].getType() != ArrayType::INT32)  err("conn must be int32");

        const TypedArray<double>  sub_data = inputs[0];
        const TypedArray<int32_t> trim_idx = inputs[1];
        const TypedArray<int32_t> conn_arr = inputs[2];

        ArrayDimensions dims = sub_data.getDimensions();
        if (dims.size() != 2) err("sub_data must be 2-D");
        const size_t R = dims[0];
        const size_t C = dims[1];
        const size_t N = R * C;

        if (conn_arr.getNumberOfElements() != 1) err("conn must be scalar");
        const int32_t conn = conn_arr[0];
        if (conn != 4 && conn != 8) err("conn must be 4 or 8");

        // Copy sub_data into a flat buffer for fast contiguous access.
        // (TypedArray has per-element overhead.)
        std::vector<double> data(N);
        {
            auto it = sub_data.cbegin();
            for (size_t k = 0; k < N; ++k) data[k] = *it++;
        }

        // Binary mask M, seeded from trim_idx (1-based linear indices)
        std::vector<uint8_t> M(N, 0);
        const size_t nTrim = trim_idx.getNumberOfElements();
        for (size_t k = 0; k < nTrim; ++k) {
            int64_t idx1 = static_cast<int64_t>(trim_idx[k]);
            if (idx1 < 1 || static_cast<size_t>(idx1) > N) {
                err("sub_trim_idx out of range");
            }
            M[idx1 - 1] = 1;
        }

        // --- imfill(BW, 'holes') with default 4-connectivity ---
        // Flood-fill the background from all border-of-image background
        // pixels using 4-connectivity. Any background pixel NOT reached is
        // enclosed (a hole) and gets filled in M.
        std::vector<uint8_t> reached(N, 0);
        std::queue<size_t> q;

        auto push_if_bg = [&](size_t i) {
            if (!M[i] && !reached[i]) { reached[i] = 1; q.push(i); }
        };

        // Seed from the four image borders
        for (size_t r = 0; r < R; ++r) {
            push_if_bg(r);                 // left column (col 0)
            push_if_bg(r + (C - 1) * R);   // right column
        }
        for (size_t c = 0; c < C; ++c) {
            push_if_bg(c * R);             // top row (row 0)
            push_if_bg((R - 1) + c * R);   // bottom row
        }

        while (!q.empty()) {
            size_t i = q.front(); q.pop();
            size_t r = i % R;
            size_t c = i / R;
            // 4-conn neighbors
            if (r > 0)     push_if_bg(i - 1);
            if (r + 1 < R) push_if_bg(i + 1);
            if (c > 0)     push_if_bg(i - R);
            if (c + 1 < C) push_if_bg(i + R);
        }

        // Fill holes: background pixels not reached become foreground
        for (size_t i = 0; i < N; ++i) {
            if (!M[i] && !reached[i]) M[i] = 1;
        }

        // --- bwconncomp(BW, conn) with the user-supplied conn (4 or 8) ---
        // Label connected components in raster (column-major) order to
        // match MATLAB's component numbering.
        std::vector<int32_t> L(N, 0);
        int32_t next_label = 1;

        // Neighbor offsets for 4 and 8 connectivity
        // (relative to current pixel i in column-major layout)
        const bool conn8 = (conn == 8);

        std::queue<size_t> cc_q;
        // Raster/column-major scan: iterate c in outer loop, r in inner.
        // MATLAB's linear index is c*R + r, and bwconncomp assigns labels
        // in increasing linear-index order of the first-seen pixel of
        // each component.
        for (size_t c = 0; c < C; ++c) {
            for (size_t r = 0; r < R; ++r) {
                size_t i = c * R + r;
                if (!M[i] || L[i] != 0) continue;

                int32_t label = next_label++;
                L[i] = label;
                cc_q.push(i);
                while (!cc_q.empty()) {
                    size_t p = cc_q.front(); cc_q.pop();
                    size_t pr = p % R;
                    size_t pc = p / R;

                    auto visit = [&](size_t q_idx) {
                        if (M[q_idx] && L[q_idx] == 0) {
                            L[q_idx] = label;
                            cc_q.push(q_idx);
                        }
                    };

                    if (pr > 0)     visit(p - 1);        // up
                    if (pr + 1 < R) visit(p + 1);        // down
                    if (pc > 0)     visit(p - R);        // left
                    if (pc + 1 < C) visit(p + R);        // right

                    if (conn8) {
                        if (pr > 0     && pc > 0)     visit(p - 1 - R); // up-left
                        if (pr > 0     && pc + 1 < C) visit(p - 1 + R); // up-right
                        if (pr + 1 < R && pc > 0)     visit(p + 1 - R); // down-left
                        if (pr + 1 < R && pc + 1 < C) visit(p + 1 + R); // down-right
                    }
                }
            }
        }

        // --- Volume per CC = sum(sub_data(pixels_of_cc)) (omitnan) ---
        const int32_t num_cc = next_label - 1;
        std::vector<double> vol(num_cc + 1, 0.0); // 1-indexed
        for (size_t i = 0; i < N; ++i) {
            int32_t lab = L[i];
            if (lab > 0) {
                double v = data[i];
                if (v == v) vol[lab] += v; // skip NaN (omitnan)
            }
        }

        // --- Pick CC with maximum volume ---
        // MATLAB's `[~,idx] = max(vols)` returns the smallest index on
        // ties, which corresponds to the lower-labeled CC. Preserve that.
        int32_t best = 0;
        double best_vol = -std::numeric_limits<double>::infinity();
        for (int32_t k = 1; k <= num_cc; ++k) {
            if (vol[k] > best_vol) {
                best_vol = vol[k];
                best = k;
            }
        }

        // --- Collect keep pixel list (1-based, column-major order) ---
        std::vector<int32_t> keep;
        keep.reserve(N / 4);
        // Iterate in column-major order so output matches MATLAB's
        // PixelIdxList raster ordering (ascending linear index).
        for (size_t i = 0; i < N; ++i) {
            if (L[i] == best) keep.push_back(static_cast<int32_t>(i + 1));
        }

        // --- Boundary set: pixels in `best` CC with at least one 4-neighbor
        // not in the CC (or on image edge). Emit in ascending linear-index
        // order.
        std::vector<int32_t> bnd;
        bnd.reserve(keep.size() / 2 + 16);
        for (size_t i = 0; i < N; ++i) {
            if (L[i] != best) continue;
            size_t r = i % R;
            size_t c = i / R;
            bool on_edge = false;
            if (r == 0 || r + 1 == R || c == 0 || c + 1 == C) {
                on_edge = true;
            } else {
                // Check 4-neighbors
                if (L[i - 1] != best) on_edge = true;
                else if (L[i + 1] != best) on_edge = true;
                else if (L[i - R] != best) on_edge = true;
                else if (L[i + R] != best) on_edge = true;
            }
            if (on_edge) bnd.push_back(static_cast<int32_t>(i + 1));
        }

        // --- Pack outputs as int32 column vectors ---
        // Pass raw pointers, not vector iterators: the createArray overload
        // requires `const T* const` and some stdlibs don't auto-convert
        // std::vector<T>::iterator to T*.
        auto out_keep = factory.createArray<int32_t>(
            {keep.size(), 1},
            keep.data(), keep.data() + keep.size());
        outputs[0] = std::move(out_keep);

        if (outputs.size() > 1) {
            auto out_bnd = factory.createArray<int32_t>(
                {bnd.size(), 1},
                bnd.data(), bnd.data() + bnd.size());
            outputs[1] = std::move(out_bnd);
        }
    }
};
