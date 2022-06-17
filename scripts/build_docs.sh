#!/bin/bash

gh-md-toc --hide-footer README.m4 | grep -v working-with-arm64 > toc.md
m4 -I./ README.m4 > README.md
