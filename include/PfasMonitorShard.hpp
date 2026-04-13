// file: include/PfasMonitorShard.hpp
#pragma once
#include <string>
#include <optional>

struct PfasMonitorRow {
    std::string nodeid;
    std::string timestamp_utc;
    double      rcalib01;
    std::string medium;
    std::string schema_tag;

    std::string              substrate_id;          // "" if none
    std::optional<double>    rpfasresid_channel;
    double                   rtox01;
    std::string              citations;
};
