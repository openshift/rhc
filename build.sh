#!/bin/bash

bundle exec rake clean version # version must be defined first
bundle exec rake package
