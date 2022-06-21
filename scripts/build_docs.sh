#!/bin/bash

gh-md-toc --hide-footer --hide-header README.m4 | grep -v -e "working-with-arm64" -e "table-of-contents" > toc.md
m4 -I./ README.m4 > README.md
