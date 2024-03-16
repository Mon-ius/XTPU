#!/bin/bash

conda create -n build python=3.12 bazel -c conda-forge
conda activate build