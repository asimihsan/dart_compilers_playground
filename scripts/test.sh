#!/usr/bin/env bash

#cd $1
pub get
dartanalyzer --options analysis_options.yaml lib test
pub run test

#flutter format --line-length 100 --set-exit-if-changed lib test example
#flutter analyze --no-current-package lib test example
#flutter test --no-pub --coverage
# resets to the original state
#cd -