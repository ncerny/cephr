#
# Cookbook Name:: cephr
# Resource:: fs
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

resource_name 'ceph_fs'

property :mount_point, String, name_property: true
property :name, String, default: 'cephfs'
property :data_pool, String, default: 'data'
property :metadata_pool, String, default: 'metadata'
property :mount_point, String, default: '/mnt/cephfs'
property :client, String, default: 'admin'
property :fuse, [TrueClass, FalseClass], default: false
property :key, String
property :keyring

action :create do
  raise 'Ceph Cluster is not available!' unless ceph_available?
  execute "ceph fs new #{new_resource.name} #{new_resource.metadata_pool} #{new_resource.data_pool}" do
    not_if 'ceph fs ls | grep -v "No filesystems enabled"'
  end
end

action :mount do
  mons = ''
  node.run_state['cephr']['monitors'].each do |_, v|
    mons += "#{v},"
  end
  mons = mons.slice(0..-2)

  if new_resource.fuse
    package 'ceph-fuse'

    execute 'Mount Ceph Filesystem as FUSE Mount' do
      command "ceph-fuse -d #{new_resource.mount_point}"
    end
  else
    opts = ''
    opts << "name=#{new_resource.client}"
    opts << "secret=#{new_resource.key}" if new_resource.key
    opts << "secretfile=#{new_resource.keyfile}" if new_resource.keyfile
    mount 'Mount Ceph Filesystem as Kernel Mount' do
      action :mount
      mount_point new_resource.mount_point
      fstype 'ceph'
      device "#{mons}:/"
      options opts
    end
  end
end

action :enable do
  mons = ''
  node.run_state['cephr']['monitors'].each do |_, v|
    mons += "#{v},"
  end
  mons = mons.slice(0..-2)

  if new_resource.fuse
    package 'ceph-fuse'


  else
    opts = ''
    opts << "name=#{new_resource.client}"
    opts << "secret=#{new_resource.key}" if new_resource.key
    opts << "secretfile=#{new_resource.keyfile}" if new_resource.keyfile
    mount 'Enable Ceph Filesystem as Kernel Mount' do
      action :enable
      mount_point new_resource.mount_point
      fstype 'cephr'
      device "#{mons}:/"
      options opts
    end
  end
end
