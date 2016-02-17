#
# Cookbook Name:: cerny_ceph
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

module CernyCeph
  module Helpers # rubocop:disable Style/Documentation
    def parse_config(config, section)
      node.run_state['ceph'] ||= {}
      node.run_state['ceph']['config'] ||= {}
      if config.is_a?(Hash)
        node.run_state['ceph']['config'] = config
      else
        config.lines.each do |line|
          line = line.strip
          if line.start_with?('[')
            section = line.slice(1..-2)
          elsif line.strip != ''
            l = line.split(' = ')
            node.run_state['ceph']['config'][section] ||= {}
            node.run_state['ceph']['config'][section][l[0]] = l[1]
          end
        end
      end
    end
  end
end
