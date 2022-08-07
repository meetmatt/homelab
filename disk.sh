#!/bin/bash

diskutil list external physical | head -n1 | awk '{print $1}'
