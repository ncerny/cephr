#
# Cookbook Name:: cephr
# Resource:: auth
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
# rubocop:disable LineLength

require_relative '../libraries/helpers'
include CephR::Helpers

resource_name 'ceph_auth'

property :entity, String, name_property: true
property :caps, [String, Hash], required: true
property :client, String
property :client_keyring, String
property :client_key, String
property :output, String

load_current_value do
  current_value_does_not_exist! unless exists?(entity)
  # cmd = Mixlib::ShellOut.new("ceph auth get #{entity}").run_command
  # current_value_does_not_exist! if cmd.error!
  # parse(cmd.stdout)
  # caps node.run_state['cephr']['auth'][entity]['caps']
  # key node.run_state['cephr']['auth'][entity]['key']
end

action :add do
  raise 'Ceph Cluster is not available!' unless ceph_available?

  # TODO: Make caps adding more robust.

  command = (current_resource ? 'caps' : 'get-or-create')
  opts = ''
  opts += " --name #{new_resource.client}" if new_resource.client
  opts += " --key #{new_resource.client_key}" if new_resource.client_key && !new_resource.client_keyring
  opts += " --keyring #{new_resource.client_keyring}" if new_resource.client_keyring
  opts += " --out-file #{new_resource.output}" if new_resource.output
  execute "ceph #{opts} auth #{command} #{new_resource.entity} #{strcaps}" do
    not_if { current_resource && current_resource.caps == new_resource.caps }
  end
end

action :delete do
  raise 'Ceph Cluster is not available!' unless ceph_available?
  execute "ceph auth del #{new_resource.entity}" do
    only_if { current_resource }
  end
end

def strcaps
  str = ''
  if caps.is_a?(Hash)
    caps.each { |k, v| str += "#{k} '#{v}' " }
    str.strip
  else
    caps
  end
end

def exists?(entity)
  require 'timeout'
  begin
    Timeout.timeout(5) do
      Mixlib::ShellOut.new("ceph auth get #{entity}").run_command.error!
      true
    end
  rescue
    false
  end
end
