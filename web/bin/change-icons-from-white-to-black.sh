#!/bin/bash

perl -i.backup -pe 's/fill="#FFFFFF"/fill="#000000"/' $*
