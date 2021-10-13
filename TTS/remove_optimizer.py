#!/usr/bin/env python3
"""Reduces model size by removing optimizer/scalar state from checkpoint"""
import sys

import torch

input_path = sys.argv[1]
output_path = sys.argv[2]

state = torch.load(input_path, map_location="cpu")

for key in ["optimizer", "scaler"]:
    state.pop(key, None)

torch.save(state, output_path)
