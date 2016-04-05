#
# Cookbook Name:: cephr
# Library:: helpers
#
# Copyright 2016 Nathan Cerny
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength

module CephR
  module Helpers # rubocop:disable Style/Documentation
    def parse_config(config, section)
      node.run_state['cephr'] ||= {}
      node.run_state['cephr']['config'] ||= {}
      if config.is_a?(Hash)
        node.run_state['cephr']['config'] = config
      else
        config.lines.each do |line|
          line = line.strip
          if line.start_with?('[')
            section = line.slice(1..-2)
          elsif line.strip != ''
            l = line.split(' = ')
            node.run_state['cephr']['config'][section] ||= {}
            node.run_state['cephr']['config'][section][l[0]] = l[1]
          end
        end
      end
    end

    def ceph_available?
      require 'timeout'
      begin
        Timeout.timeout(5) do
          cmd = Mixlib::ShellOut.new('ceph mon_status').run_command
          cmd.error!
          true
        end
      rescue
        false
      end
    end
  end
end
