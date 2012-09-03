#!/bin/bash

rake clean version # version must be defined first
rake package
gem uninstall rhc -x
gem install pkg/*.gem
