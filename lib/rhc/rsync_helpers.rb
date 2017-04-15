###
# ssh_key_helpers.rb - methods to help manipulate ssh keys
#
# Copyright 2012 Red Hat, Inc. and/or its affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
#  limitations under the License.

require 'httpclient'

module RHC
  module RsyncHelpers

    def exe?(executable)
      ENV['PATH'].split(File::PATH_SEPARATOR).any? do |directory|
        File.executable?(File.join(directory, executable.to_s))
      end
    end

    # check the version of SSH that is installed
    def rsync_version
      @rsync_version ||= `rsync --version 2>&1`.strip
    end

    # return whether or not SSH is installed
    def has_rsync?
      @has_rsync ||= begin
        @rsync_version = nil
        rsync_version
        $?.success?
      rescue
        false
      end
    end

    # return supplied ssh executable, if valid (executable, searches $PATH).
    # if none was supplied, return installed ssh, if any.
    def check_rsync_executable!(path)
      if not path
        raise RHC::InvalidRsyncExecutableException.new("No system rsync available. Please use the --rsync option to specify the path to your rsync executable, or install rsync.") unless has_rsync?
        'rsync'
      else
        bin_path = path.split(' ').first
        raise RHC::InvalidRsyncExecutableException.new("rsync executable '#{bin_path}' does not exist.") unless File.exist?(bin_path) or exe?(bin_path)
        raise RHC::InvalidRsyncExecutableException.new("rsync executable '#{bin_path}' is not executable.") unless File.executable?(bin_path) or exe?(bin_path)
        path
      end
    end

  end
end
