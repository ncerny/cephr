#
# Cookbook Name:: cerny_ceph
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
include CernyCeph::Helpers

resource_name 'ceph_fs'

property :name, String, name_property: true
property :data_pool, String, default: 'data'
property :metadata_pool, String, default: 'metadata'
property :mount_point, String, default: '/mnt/cephfs'
property :client, String, default: 'admin'
property :key, String

action :create do
  execute "ceph fs new #{new_resource.name} #{new_resource.metadata_pool} #{new_resource.data_pool}" do
    not_if 'ceph fs ls'
  end
end

action :mount do

end

action :fuse do

end
