// file: src/QpuLinterMain.cpp
#include "QpuSchema.hpp"
#include "QpuInvariants.hpp"
#include "QpuCsvIo.hpp"
#include <iostream>

int main(int argc, char** argv) {
    if (argc < 2) {
        std::cerr << "Usage: qpu-lint <csv>\n";
        return 1;
    }
    auto rows = qpudata::read_qpudata_csv(argv[1]);
    std::size_t bad = 0;
    for (std::size_t i = 0; i < rows.size(); ++i) {
        if (!qpudata::all_invariants_hold(rows[i])) {
            std::cerr << "Invariant failure on row " << (i+1) << "\n";
            ++bad;
        }
    }
    return bad == 0 ? 0 : 2;
}
