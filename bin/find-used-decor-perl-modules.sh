#!/bin/bash

egrep -h '^(use|require) ' ../core ../shared ../web  -r | sort | uniq | grep -v 'use lib' | grep -v 'Decor::' | grep -v 'Web::Reactor::' | grep '::'
