// file: include/QpuInvariants.hpp
#pragma once
#include "QpuSchema.hpp"

namespace qpudata {

inline bool rpfasresid_required_if_substrate(const QpuRow& row) {
    const bool has_sub = !row.substrate_id.empty();
    const bool has_rpfas = row.rpfasresid_channel.has_value();
    return (!has_sub) || has_rpfas;
}

// aggregate
inline bool all_invariants_hold(const QpuRow& row) {
    if (!rpfasresid_required_if_substrate(row)) return false;
    // add corridorpresent/safestep-style checks, range checks, etc.
    return true;
}

} // namespace qpudata
