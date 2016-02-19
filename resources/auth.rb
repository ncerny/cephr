#
# Cookbook Name:: cerny_ceph
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

resource_name 'ceph_auth'

property :entity, String, name_property: true
property :caps, [String, Hash], required: true
property :secret, String
property :keyring, String
property :uid, Integer

load_current_value do
  current_value_does_not_exist! unless exists?(entity)
  # cmd = Mixlib::ShellOut.new("ceph auth get #{entity}").run_command
  # current_value_does_not_exist! if cmd.error!
  # parse(cmd.stdout)
  # caps node.run_state['ceph']['auth'][entity]['caps']
  # key node.run_state['ceph']['auth'][entity]['key']
end

action :add do
  execute "ceph auth add #{new_resource.entity} #{strcaps}" do
    not_if { current_resource }
  end

  execute "ceph auth caps #{new_resource.entity} #{strcaps}" do
    only_if { current_resource && current_resource.caps != new_resource.caps }
  end
end

action :write do
  directory ::File.dirname(new_resource.keyring) do
    owner 'ceph'
    group 'ceph'
    mode '0750'
    recursive true
  end

  execute "Create #{entity} Keyring" do
    command "ceph-authtool --create-keyring #{new_resource.keyring} --add-key=#{new_resource.secret} --name #{new_resource.entity} #{(new_resource.uid ? "--set-uid=#{new_resource.uid}" : '')} #{strcaps}"
    user 'ceph'
    creates new_resource.keyring
  end
end

action :delete do
  execute "ceph auth del #{new_resource.entity}" do
    only_if { current_resource }
  end
end

def strcaps
  str = ''
  if caps.is_a?(Hash)
    caps.each { |k, v| str += "--cap #{k} '#{v}' " }
    str.strip
  else
    caps
  end
end

def exists?(entity)
  Mixlib::ShellOut.new("ceph auth get #{entity}").run_command.error!
  true
rescue
  false
end
